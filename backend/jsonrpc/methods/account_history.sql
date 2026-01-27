SET ROLE hafah_owner;

/*
 * account_history.sql: get_account_history JSON-RPC method implementation.
 *
 * Called by: hafah_backend.ah_get_account_history_json() in formatters/account_history.sql
 *
 * JSON-RPC Method: account_history_api.get_account_history
 *
 * Returns operation history for a specific account with filtering and pagination.
 */

/*
 * ===================================================================================
 * ah_get_account_history
 * ===================================================================================
 * PURPOSE: Retrieve account operation history with filtering by operation type.
 *
 * DATA FLOW:
 *   1. Validate input parameters (limit, start/limit relationship)
 *   2. Handle empty filter case (return empty)
 *   3. Translate filter bitmask to operation type IDs
 *   4. Determine upper block limit based on reversibility
 *   5. Resolve account name to ID
 *   6. Query account_operations_view with optional type filter
 *   7. Join with operations for body and transaction info
 *   8. Join with blocks for timestamp
 *   9. Return formatted results ordered by operation sequence
 *
 * PARAMETERS:
 *   - _filter_low: Low 64 bits of operation type bitmask
 *   - _filter_high: High 64 bits of operation type bitmask
 *   - _account: Account name to query
 *   - _start: Starting operation sequence number (descending)
 *   - _limit: Maximum operations to return
 *   - _include_reversible: Include reversible blocks
 *   - _is_legacy_style: Format operations in legacy style
 *
 * RETURNS: Table of account operations with metadata
 */
CREATE OR REPLACE FUNCTION hafah_backend.ah_get_account_history(
    _filter_low         BIGINT,
    _filter_high        BIGINT,
    _account            VARCHAR,
    _start              BIGINT,
    _limit              BIGINT,
    _include_reversible BOOLEAN,
    _is_legacy_style    BOOLEAN
)
RETURNS TABLE(
    _trx_id       TEXT,
    _block        INT,
    _trx_in_block BIGINT,
    _op_in_trx    BIGINT,
    _virtual_op   BOOLEAN,
    _timestamp    TEXT,
    _value        TEXT,
    _operation_id INT
)
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_generic_plan
AS $$
DECLARE
  __resolved_filter   SMALLINT[];
  __account_id        INT;
  __upper_block_limit INT;
  __use_filter        INT;
BEGIN
  /*
   * Input Validation
   */
  PERFORM hafah_backend.validate_limit(_limit, 1000);
  PERFORM hafah_backend.validate_start_limit(_start, _limit);

  /*
   * Empty Filter Check:
   *   If both filter parts are 0, no types selected - return empty
   */
  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL))
     AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    RETURN QUERY SELECT
      NULL::TEXT,
      NULL::INT,
      NULL::BIGINT,
      NULL::BIGINT,
      NULL::BOOLEAN,
      NULL::TEXT,
      NULL::TEXT,
      NULL::INT
    LIMIT 0;
    RETURN;
  END IF;

  /*
   * Translate filter bitmask to array of operation type IDs
   */
  SELECT hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high)
  INTO __resolved_filter;

  /*
   * Determine Upper Block Limit:
   *   - Reversible: use latest block
   *   - Irreversible only: use last irreversible block
   */
  IF _include_reversible THEN
    SELECT num FROM hive.blocks_view ORDER BY num DESC LIMIT 1 INTO __upper_block_limit;
  ELSE
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;

  /*
   * Resolve Account ID:
   *   - Reversible: use accounts_view (includes reversible)
   *   - Irreversible: use hafd.accounts (base table)
   */
  IF _include_reversible THEN
    SELECT INTO __account_id (SELECT id FROM hive.accounts_view WHERE name = _account);
  ELSE
    SELECT INTO __account_id (SELECT id FROM hafd.accounts WHERE name = _account);
  END IF;

  __use_filter := array_length(__resolved_filter, 1);

  RETURN QUERY
    WITH pre_result AS (
      SELECT
        /*
         * Transaction ID:
         *   Virtual ops have negative trx_in_block, use placeholder
         */
        (
          CASE
            WHEN ho.trx_in_block < 0
              THEN '0000000000000000000000000000000000000000'
            ELSE encode(
              (
                SELECT htv.trx_hash
                FROM hive.transactions_view htv
                WHERE ho.trx_in_block >= 0
                  AND ds.block_num = htv.block_num
                  AND ho.trx_in_block = htv.trx_in_block
              ),
              'hex'
            )
          END
        ) AS _trx_id,
        ds.block_num AS _block,
        (
          CASE
            WHEN ho.trx_in_block < 0
              THEN 4294967295
            ELSE ho.trx_in_block
          END
        ) AS _trx_in_block,
        ho.op_pos::BIGINT AS _op_in_trx,
        hot.is_virtual AS virtual_op,
        (
          CASE
            WHEN _is_legacy_style
              THEN hive.get_legacy_style_operation(ho.body_binary)::TEXT
            ELSE ho.body::TEXT
          END
        ) AS _value,
        ds.account_op_seq_no AS _operation_id
      FROM (
        /*
         * Query Strategy:
         *   Use UNION ALL to handle filtered vs unfiltered queries separately
         *   This allows better query plan optimization
         */
        WITH accepted_types AS MATERIALIZED (
          SELECT ot.id
          FROM hafd.operation_types ot
          WHERE __use_filter IS NOT NULL
            AND ot.id = ANY(__resolved_filter)
        )
        /*
         * Branch 1: With operation type filter
         */
        (
          SELECT hao.operation_id, hao.op_type_id, hao.block_num, hao.account_op_seq_no
          FROM hive.account_operations_view hao
          JOIN accepted_types t ON hao.op_type_id = t.id
          WHERE __use_filter IS NOT NULL
            AND hao.account_id = __account_id
            AND hao.account_op_seq_no <= _start
            AND hao.block_num <= __upper_block_limit
          ORDER BY hao.account_op_seq_no DESC
          LIMIT _limit
        )
        UNION ALL
        /*
         * Branch 2: Without operation type filter (all types)
         */
        (
          SELECT hao.operation_id, hao.op_type_id, hao.block_num, hao.account_op_seq_no
          FROM hive.account_operations_view hao
          WHERE __use_filter IS NULL
            AND hao.account_id = __account_id
            AND hao.account_op_seq_no <= _start
            AND hao.block_num <= __upper_block_limit
          ORDER BY hao.account_op_seq_no DESC
          LIMIT _limit
        )
      ) ds
      JOIN LATERAL (
        SELECT hov.body, hov.body_binary, hov.op_pos, hov.trx_in_block
        FROM hive.operations_view hov
        WHERE ds.operation_id = hov.id
      ) ho ON TRUE
      JOIN LATERAL (
        SELECT ot.is_virtual
        FROM hafd.operation_types ot
        WHERE ds.op_type_id = ot.id
      ) hot ON TRUE
      ORDER BY ds.account_op_seq_no ASC
    )
    SELECT
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result.virtual_op,
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS formated_timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM pre_result
    JOIN hive.blocks_view hb ON hb.num = pre_result._block
    ORDER BY pre_result._operation_id ASC;
END
$$;

RESET ROLE;
