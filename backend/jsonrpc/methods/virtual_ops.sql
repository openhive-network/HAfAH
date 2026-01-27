SET ROLE hafah_owner;

/*
 * virtual_ops.sql: enum_virtual_ops JSON-RPC method implementation.
 *
 * Called by: hafah_backend.enum_virtual_ops_json() in formatters/virtual_ops.sql
 *
 * JSON-RPC Method: account_history_api.enum_virtual_ops
 *
 * Returns virtual operations within a block range with filtering and pagination.
 */

/*
 * Result type for enum_virtual_ops function
 */
DROP TYPE IF EXISTS hafah_backend.enum_virtual_ops_result CASCADE;
CREATE TYPE hafah_backend.enum_virtual_ops_result AS (
    _trx_id       TEXT,
    _block        INT,
    _trx_in_block BIGINT,
    _op_in_trx    BIGINT,
    _virtual_op   BOOLEAN,
    _timestamp    TEXT,
    _value        TEXT,
    _operation_id BIGINT
);

/*
 * ===================================================================================
 * enum_virtual_ops
 * ===================================================================================
 * PURPOSE: Enumerate virtual operations within a block range with filtering.
 *
 * DATA FLOW:
 *   1. Validate input parameters (limit, block range)
 *   2. Handle empty filter case (return empty)
 *   3. Resolve operation type filter to array of type IDs
 *   4. Apply reversibility constraints to block range
 *   5. Query virtual operations from helper_operations_view
 *   6. Join with transactions for hash (if applicable)
 *   7. Join with blocks for timestamp
 *   8. Return formatted results
 *
 * PARAMETERS:
 *   - _filter: Bitmask of operation types to include (NULL = all)
 *   - _block_range_begin: Start block (inclusive)
 *   - _block_range_end: End block (exclusive)
 *   - _operation_begin: Starting operation ID for pagination (-1 = from start)
 *   - _limit: Maximum operations to return
 *   - _include_reversible: Include reversible blocks
 *
 * RETURNS: Set of virtual operations with metadata
 */
CREATE OR REPLACE FUNCTION hafah_backend.enum_virtual_ops(
    _filter             BIGINT,
    _block_range_begin  INT,
    _block_range_end    INT,
    _operation_begin    BIGINT,
    _limit              INT,
    _include_reversible BOOLEAN
)
RETURNS SETOF hafah_backend.enum_virtual_ops_result
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __resolved_filter   SMALLINT[];
  __upper_block_limit INT;
  __filter_info       INT;
BEGIN
  /*
   * Input Validation
   */
  PERFORM hafah_backend.validate_negative_limit(_limit);
  PERFORM hafah_backend.validate_limit(_limit, 150000);
  PERFORM hafah_backend.validate_block_range(_block_range_begin, _block_range_end, 2000);

  /*
   * Empty Filter Check:
   *   If filter is explicitly 0 (no types), return empty result
   */
  IF (NOT (_filter IS NULL)) AND _filter = 0 THEN
    RETURN QUERY SELECT
      NULL::TEXT,    -- _trx_id
      NULL::INT,     -- _block
      NULL::BIGINT,  -- _trx_in_block
      NULL::BIGINT,  -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT,    -- _timestamp
      NULL::TEXT,    -- _value
      NULL::BIGINT   -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  /*
   * Translate bitmask filter to array of operation type IDs
   */
  SELECT hafah_backend.translate_enum_virtual_ops_filter(_filter) INTO __resolved_filter;
  SELECT INTO __filter_info (SELECT array_length(__resolved_filter, 1));

  /*
   * Reversibility Constraint:
   *   If not including reversible, clamp block range to irreversible
   */
  IF NOT _include_reversible THEN
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
    IF _block_range_begin > __upper_block_limit THEN
      RETURN QUERY SELECT
        NULL::TEXT,
        NULL::INT,
        NULL::BIGINT,
        NULL::BIGINT,
        NULL::BOOLEAN,
        NULL::TEXT,
        NULL::TEXT,
        NULL::BIGINT
      LIMIT 0;
      RETURN;
    ELSIF __upper_block_limit <= _block_range_end THEN
      SELECT __upper_block_limit INTO _block_range_end;
    END IF;
  END IF;

  RETURN QUERY
    WITH pre_result AS (
      SELECT
        /*
         * Transaction ID:
         *   Virtual ops may not have a transaction, use placeholder
         */
        (
          CASE
            WHEN T2.trx_hash IS NULL
              THEN '0000000000000000000000000000000000000000'
            ELSE encode(T2.trx_hash, 'hex')
          END
        ) AS _trx_id,
        T.block_num AS _block,
        (
          CASE
            WHEN T2.trx_in_block IS NULL
              THEN 4294967295
            ELSE T2.trx_in_block
          END
        ) AS _trx_in_block,
        T.op_pos AS _op_in_trx,
        T.virtual_op AS _virtual_op,
        T.body::TEXT AS _value,
        T.id AS _operation_id
      FROM (
        SELECT
          ho.id,
          ho.block_num,
          ho.trx_in_block,
          ho.op_pos,
          ho.body,
          ho.op_type_id,
          ho.virtual_op
        FROM hafah_backend.helper_operations_view ho
        WHERE ho.block_num >= _block_range_begin
          AND ho.block_num < _block_range_end
          AND ho.virtual_op = TRUE
          AND ((__filter_info IS NULL) OR (ho.op_type_id IN (SELECT * FROM unnest(__resolved_filter))))
          AND (_operation_begin = -1 OR ho.id >= _operation_begin)
        ORDER BY ho.id
        LIMIT _limit
      ) T
      LEFT JOIN (
        SELECT block_num, trx_in_block, trx_hash
        FROM hive.transactions_view ht
        WHERE ht.block_num >= _block_range_begin
          AND ht.block_num < _block_range_end
      ) T2
        ON T.block_num = T2.block_num
        AND T.trx_in_block = T2.trx_in_block
      WHERE T.block_num >= _block_range_begin
        AND T.block_num < _block_range_end
      ORDER BY T.id
      LIMIT _limit
    )
    SELECT
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result._virtual_op,
      trim(both '"' from to_json(hb.created_at)::TEXT) AS _timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM pre_result
    JOIN hive.blocks_view hb ON hb.num = pre_result._block
    WHERE hb.num >= _block_range_begin
      AND hb.num < _block_range_end
    ORDER BY pre_result._operation_id;
END
$$;

RESET ROLE;
