SET ROLE hafah_owner;

/*
 * account_history.sql: get_account_history JSON-RPC method implementation.
 *
 * Called by: hafah_backend.ah_get_account_history_json() in formatters/account_history.sql
 *
 * JSON-RPC Method: account_history_api.get_account_history
 *
 * Returns operation history for a specific account with filtering and pagination.
 *
 * 128-BIT OPERATION TYPE FILTER:
 *   Hive uses a 128-bit bitmask to filter operation types. Each bit position
 *   corresponds to an operation type ID. The filter is split into two 64-bit
 *   parts for JSON transmission:
 *
 *     _filter_low:  Bits 0-63  (operation types 0-63)
 *     _filter_high: Bits 64-127 (operation types 64-127)
 *
 *   Example: To filter for vote_operation (type 0) and comment_operation (type 1):
 *     _filter_low = 3 (binary: 11), _filter_high = 0
 *
 *   NULL filter means "all types". Zero filter means "no types" (empty result).
 *
 *   The translate_get_account_history_filter() function converts this bitmask
 *   to an array of operation type IDs for use in SQL queries.
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
    _value        JSONB,
    _operation_id INT
)
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_generic_plan
AS $$
DECLARE
  __resolved_filter   SMALLINT[];  -- Array of operation type IDs from bitmask
  __account_id        INT;         -- Resolved numeric account ID
  __upper_block_limit INT;         -- Block limit based on reversibility
  __use_filter        INT;         -- NULL if no filter, length otherwise
BEGIN
  /*
   * INPUT VALIDATION:
   *   - Limit must be <= 1000 (API maximum)
   *   - Start must be >= limit-1 (ensures valid window)
   */
  PERFORM hafah_backend.validate_limit(_limit, 1000);
  PERFORM hafah_backend.validate_start_limit(_start, _limit);

  /*
   * EMPTY FILTER CHECK:
   *   128-bit filter split into low/high 64-bit parts:
   *   - NULL + NULL = all types (no filtering)
   *   - 0 + 0 = no types (return empty result)
   *   - Any non-zero = specific types
   *
   * WHY COALESCE: Handle NULL values in addition (NULL + 0 = NULL, not 0)
   */
  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL))
     AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    -- WHY: Zero filter explicitly means "no operations" - fast exit
    RETURN QUERY SELECT
      NULL::TEXT,
      NULL::INT,
      NULL::BIGINT,
      NULL::BIGINT,
      NULL::BOOLEAN,
      NULL::TEXT,
      NULL::JSONB,
      NULL::INT
    LIMIT 0;
    RETURN;
  END IF;

  /*
   * BITMASK TO TYPE ID TRANSLATION:
   *   Convert 128-bit bitmask to array of SMALLINT operation type IDs.
   *   Example: filter_low=5 (binary 101) → [0, 2] (types at bit positions 0 and 2)
   *
   *   See: backend/utilities/bit_operations.sql for implementation
   */
  SELECT hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high)
  INTO __resolved_filter;

  /*
   * REVERSIBILITY HANDLING:
   *   Hive has "reversible" blocks that may be reorganized.
   *   irreversible_block = last confirmed block that won't change.
   *
   *   - include_reversible=TRUE: Return ops up to latest block (may change)
   *   - include_reversible=FALSE: Only return ops in finalized blocks
   */
  IF _include_reversible THEN
    SELECT num FROM hive.blocks_view ORDER BY num DESC LIMIT 1 INTO __upper_block_limit;
  ELSE
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;

  /*
   * ACCOUNT NAME TO ID RESOLUTION:
   *   Account operations are indexed by numeric ID, not name.
   *   Resolution source depends on reversibility:
   *   - accounts_view: Includes accounts from reversible blocks
   *   - hafd.accounts: Only finalized accounts
   *
   * TIMING: Resolved once here, not in the query, for efficiency.
   */
  IF _include_reversible THEN
    SELECT INTO __account_id (SELECT id FROM hive.accounts_view WHERE name = _account);
  ELSE
    SELECT INTO __account_id (SELECT id FROM hafd.accounts WHERE name = _account);
  END IF;

  -- WHY: NULL means no filter (all types), non-NULL means filtered query
  __use_filter := array_length(__resolved_filter, 1);

  RETURN QUERY
    /*
     * ===================================================================================
     * MAIN QUERY: Account History Retrieval
     * ===================================================================================
     * PERFORMANCE: Uses UNION ALL pattern for filtered/unfiltered query optimization.
     *              PostgreSQL can optimize each branch independently based on __use_filter.
     */
    WITH pre_result AS (
      SELECT
        /*
         * TRANSACTION ID:
         *   - Regular ops: 40-char hex hash from transactions_view
         *   - Virtual ops: Use placeholder (40 zeros)
         *
         * NOTE: trx_in_block < 0 indicates a virtual operation (no real transaction)
         */
        (
          CASE
            WHEN (SELECT trx_in_block FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0)) < 0
              THEN '0000000000000000000000000000000000000000'
            ELSE encode(
              (
                SELECT htv.trx_hash
                FROM hive.transactions_view htv
                WHERE (SELECT trx_in_block FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0)) >= 0
                  AND ds.block_num = htv.block_num
                  AND (SELECT trx_in_block FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0)) = htv.trx_in_block
              ),
              'hex'
            )
          END
        ) AS _trx_id,
        ds.block_num AS _block,
        /*
         * TRANSACTION IN BLOCK:
         *   - Regular ops: 0-based index within block
         *   - Virtual ops: 4294967295 (max uint32, signals "no transaction")
         */
        (
          CASE
            WHEN (SELECT trx_in_block FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0)) < 0
              THEN 4294967295  -- WHY: Max uint32 = "no transaction" marker
            ELSE (SELECT trx_in_block FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0))
          END
        ) AS _trx_in_block,
        (SELECT op_pos FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0))::BIGINT AS _op_in_trx,
        (SELECT is_virtual FROM hafd.operation_types WHERE id = ds.op_type_id) AS virtual_op,
        /*
         * OPERATION BODY FORMAT:
         *   - Legacy: Old format with type as string key {"vote": {...}}
         *   - New: Structured format {"type": "vote_operation", "value": {...}}
         *
         * WHY SCALAR SUBQUERIES instead of LATERAL JOIN:
         *   PostgreSQL's join planner materializes the entire operations hypertable
         *   when using LATERAL JOIN, scanning all 20M+ rows including decompressing
         *   compressed chunks. Scalar subqueries force per-row evaluation with
         *   TimescaleDB chunk exclusion (ChunkAppend), going from ~19s to ~0.5ms
         *   for 1000 rows.
         */
        (
          CASE
            WHEN _is_legacy_style
              THEN hive.get_legacy_style_operation(hafd._operation_from_jsonb(
                (SELECT body FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0))
              ))::JSONB
            ELSE (SELECT body FROM hive.operations_view WHERE id = ds.operation_id
                  AND id >= hafd.operation_id(ds.block_num, 0) AND id < hafd.operation_id(ds.block_num + 1, 0))
          END
        ) AS _value,
        ds.account_op_seq_no AS _operation_id
      FROM (
        /*
         * UNION ALL QUERY OPTIMIZATION PATTERN:
         *   Why not a single query with OR condition?
         *   - PostgreSQL optimizes each UNION branch independently
         *   - Filtered query uses index on (account_id, op_type_id, account_op_seq_no)
         *   - Unfiltered query uses index on (account_id, account_op_seq_no)
         *   - Single query with OR would scan both paths inefficiently
         *
         * WHY MATERIALIZED: accepted_types CTE prevents repeated evaluation
         */
        WITH accepted_types AS MATERIALIZED (
          SELECT ot.id
          FROM hafd.operation_types ot
          WHERE __use_filter IS NOT NULL
            AND ot.id = ANY(__resolved_filter)
        )
        /*
         * BRANCH 1: WITH FILTER
         *   Activated when __use_filter IS NOT NULL (specific operation types requested)
         *   JOIN on accepted_types filters to only requested operation types
         */
        (
          SELECT hao.operation_id, hao.op_type_id, hao.block_num, hao.account_op_seq_no
          FROM hive.account_operations_view hao
          JOIN accepted_types t ON hao.op_type_id = t.id
          WHERE __use_filter IS NOT NULL
            AND hao.account_id = __account_id
            AND hao.account_op_seq_no <= _start  -- WHY: Descending from start
            AND hao.block_num <= __upper_block_limit
          ORDER BY hao.account_op_seq_no DESC  -- WHY: Most recent first
          LIMIT _limit
        )
        UNION ALL
        /*
         * BRANCH 2: WITHOUT FILTER (all operation types)
         *   Activated when __use_filter IS NULL (no filter or NULL filter)
         *   Simpler query without JOIN, uses different index
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
      ORDER BY ds.account_op_seq_no ASC  -- WHY: Final result ordered ascending (oldest first in array)
    )
    SELECT
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result.virtual_op,
      /*
       * TIMESTAMP FORMATTING:
       *   Block timestamp in ISO 8601 format without quotes.
       *   btrim removes quotes added by to_json().
       */
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS formated_timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM pre_result
    JOIN hive.blocks_view hb ON hb.num = pre_result._block  -- WHY: Get block timestamp
    ORDER BY pre_result._operation_id ASC;  -- WHY: Return in ascending sequence order
END
$$;

RESET ROLE;
