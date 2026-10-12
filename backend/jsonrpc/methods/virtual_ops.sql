SET ROLE hafah_owner;

/*
 * virtual_ops.sql: enum_virtual_ops JSON-RPC method implementation.
 *
 * Called by: hafah_backend.enum_virtual_ops_json() in formatters/virtual_ops.sql
 *
 * JSON-RPC Method: account_history_api.enum_virtual_ops
 *
 * Returns virtual operations within a block range with filtering and pagination.
 *
 * 64-BIT OPERATION TYPE FILTER:
 *   Unlike get_account_history which uses 128-bit filter (split into low/high),
 *   enum_virtual_ops uses a single 64-bit bitmask. This is sufficient because
 *   virtual operations only use a subset of operation types.
 *
 *   - NULL filter: All virtual operation types
 *   - 0 filter: No types (returns empty)
 *   - Non-zero: Specific types (bit position = operation type ID)
 *
 * BLOCK RANGE:
 *   - _block_range_begin: Start block (inclusive)
 *   - _block_range_end: End block (EXCLUSIVE)
 *   - Maximum range: 2000 blocks
 *
 * PAGINATION:
 *   Uses _operation_begin for cursor-based pagination:
 *   - -1: Start from beginning of range
 *   - >0: Continue from this operation ID (for next page)
 */

/*
 * RESULT TYPE: enum_virtual_ops_result
 */
DROP TYPE IF EXISTS hafah_backend.enum_virtual_ops_result CASCADE;
CREATE TYPE hafah_backend.enum_virtual_ops_result AS (
    _trx_id       TEXT,    -- Always 40 zeros (virtual ops have no transaction)
    _block        INT,     -- Block number containing this operation
    _trx_in_block BIGINT,  -- Always 4294967295 (no transaction)
    _op_in_trx    BIGINT,  -- Operation position
    _virtual_op   BOOLEAN, -- Always TRUE for this endpoint
    _timestamp    TEXT,    -- Block timestamp in ISO 8601
    _value        JSONB,   -- Operation body as JSONB
    _operation_id BIGINT   -- Global operation ID (for pagination)
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
 *   4. Clamp the block range to the last irreversible block
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
 *   - _irreversible_block: Last irreversible block, when the caller already has it
 *
 * Only irreversible blocks are served: the JSON-RPC include_reversible argument
 * does not reach this function, and even when it is true no operation from a
 * reversible block is returned.
 *
 * RETURNS: Set of virtual operations with metadata
 */
CREATE OR REPLACE FUNCTION hafah_backend.enum_virtual_ops(
    _filter             BIGINT,
    _block_range_begin  INT,
    _block_range_end    INT,
    _operation_begin    BIGINT,
    _limit              INT,
    _irreversible_block INT DEFAULT NULL
)
RETURNS SETOF hafah_backend.enum_virtual_ops_result
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __resolved_filter   SMALLINT[];  -- Array of operation type IDs from bitmask
  __upper_block_limit INT;         -- Last irreversible block
  __filter_info       INT;         -- NULL if no filter, array length otherwise
BEGIN
  /*
   * INPUT VALIDATION:
   *   - Limit must be positive (negative not allowed unlike account history)
   *   - Limit maximum: 150000 operations
   *   - Block range maximum: 2000 blocks
   */
  PERFORM hafah_backend.validate_negative_limit(_limit);
  PERFORM hafah_backend.validate_limit(_limit, 150000);
  PERFORM hafah_backend.validate_block_range(_block_range_begin, _block_range_end, 2000);

  /*
   * EMPTY FILTER CHECK:
   *   Filter = 0 explicitly means "no operation types wanted".
   *   This is different from NULL which means "all types".
   *
   * WHY fast exit: No point querying database if result will be empty.
   */
  IF (NOT (_filter IS NULL)) AND _filter = 0 THEN
    RETURN QUERY SELECT
      NULL::TEXT,    -- _trx_id
      NULL::INT,     -- _block
      NULL::BIGINT,  -- _trx_in_block
      NULL::BIGINT,  -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT,    -- _timestamp
      NULL::JSONB,   -- _value
      NULL::BIGINT   -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  /*
   * 64-BIT BITMASK TO TYPE ID TRANSLATION:
   *   Convert single 64-bit filter to array of operation type IDs.
   *
   *   Example: _filter = 5 (binary: 101)
   *   Result: ARRAY[0, 2] (operation types at bit positions 0 and 2)
   *
   *   See: backend/utilities/bit_operations.sql for implementation
   */
  SELECT hafah_backend.translate_enum_virtual_ops_filter(_filter) INTO __resolved_filter;
  SELECT INTO __filter_info (SELECT array_length(__resolved_filter, 1));

  /*
   * IRREVERSIBLE DATA ONLY:
   *   Data from blocks that may be reorganized (reverted) is never returned.
   *
   *   Strategy:
   *   1. Get last irreversible block number
   *   2. If entire range is reversible: return empty
   *   3. If range spans reversible: clamp the exclusive end to irreversible block + 1,
   *      so the irreversible block itself is still served
   */
  __upper_block_limit := COALESCE(_irreversible_block, hive.app_get_irreversible_block());

  -- WHY: Entire range is in reversible territory - nothing to return
  IF _block_range_begin > __upper_block_limit THEN
    RETURN;
  -- WHY: Partial range in reversible - clamp to irreversible boundary (end is exclusive)
  ELSIF __upper_block_limit < _block_range_end THEN
    _block_range_end := __upper_block_limit + 1;
  END IF;

  RETURN QUERY
    /*
     * ===================================================================================
     * MAIN QUERY: Virtual Operations Enumeration
     * ===================================================================================
     * STRATEGY:
     *   1. Inner query (T): Select virtual ops from helper_operations_view
     *   2. LEFT JOIN transactions: For completeness (usually NULL for virtual ops)
     *   3. JOIN blocks: Get timestamp
     *   4. Order by operation_id for consistent pagination
     */
    WITH pre_result AS (
      SELECT
        /*
         * TRANSACTION ID:
         *   Virtual operations generally don't have transactions.
         *   Some edge cases exist where virtual ops reference transactions,
         *   but most will be NULL → 40-char zero placeholder.
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
              THEN 4294967295  -- WHY: Max uint32 signals "no transaction"
            ELSE T2.trx_in_block
          END
        ) AS _trx_in_block,
        T.op_pos AS _op_in_trx,
        T.virtual_op AS _virtual_op,
        T.body AS _value,
        T.id AS _operation_id
      FROM (
        /*
         * INNER QUERY: Virtual Operations Selection
         *
         * Filters applied:
         *   1. Block range (begin inclusive, end exclusive)
         *   2. Virtual operations only (ho.virtual_op = TRUE)
         *   3. Operation type filter (if specified)
         *   4. Pagination cursor (if specified)
         */
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
          AND ho.block_num < _block_range_end  -- WHY: Exclusive end for consistent pagination
          AND ho.virtual_op = TRUE             -- WHY: Only virtual operations
          /*
           * OPERATION TYPE FILTER:
           *   __filter_info IS NULL: No filter, accept all types
           *   __filter_info NOT NULL: Filter to specific types from bitmask
           *
           * WHY unnest: Convert SMALLINT[] to rows for IN clause
           */
          AND ((__filter_info IS NULL) OR (ho.op_type_id = ANY(__resolved_filter)))
          /*
           * PAGINATION CURSOR:
           *   _operation_begin = -1: Start from beginning of range
           *   _operation_begin > 0: Continue from this operation ID
           *
           * WHY: Enables efficient cursor-based pagination for large result sets
           */
          AND (_operation_begin = -1 OR ho.id >= _operation_begin)
        ORDER BY ho.id  -- WHY: Consistent ordering for pagination
        LIMIT _limit
      ) T
      /*
       * TRANSACTION JOIN:
       *   LEFT JOIN because most virtual ops won't match a transaction.
       *   Restricted to same block range for efficiency.
       */
      LEFT JOIN LATERAL (
        -- LIMIT 1: a position holds one transaction (its index is not declared unique)
        SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
        WHERE tx.block_num = T.block_num AND tx.trx_in_block = T.trx_in_block
        LIMIT 1
      ) T2 ON TRUE
    )
    SELECT
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result._virtual_op,
      -- WHY trim: Remove quotes added by to_json for clean ISO 8601 timestamp
      trim(both '"' from to_json(hb.created_at)::TEXT) AS _timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM pre_result
    JOIN hafd.blocks hb ON hb.num = pre_result._block  -- WHY: Get block timestamp
    ORDER BY pre_result._operation_id;  -- WHY: Consistent ordering for client consumption
END
$$;

RESET ROLE;
