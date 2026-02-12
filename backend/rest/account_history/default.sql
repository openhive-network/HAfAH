SET ROLE hafah_owner;

/*
 * ===================================================================================
 * default.sql: Default account history implementation (no filters)
 * ===================================================================================
 * Called by: hafah_backend.get_ops_by_account() in backend/rest/account_history/router.sql
 *
 * Used when: No operation type filter AND (participation_mode='all' OR no account filter)
 *
 * STRATEGY:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * This is the simplest implementation - returns ALL operations for an account within
 * a block range, with no additional filtering.
 *
 * Because there's no filter complexity, we can:
 *   1. Calculate exact total count using get_account_operations_count()
 *   2. Use standard pagination with known page count
 *   3. Apply offset directly in the WHERE clause for better performance
 *
 * PAGINATION:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Uses DESCENDING order (newest operations first):
 *   - Page 1 = most recent operations
 *   - Higher page numbers = older operations
 *   - Offset subtracted from to_seq rather than using OFFSET clause
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: account_history_default
 * ===================================================================================
 * PURPOSE: Retrieve account operations without any filtering. Returns all operations
 *          for the specified account within the given block range.
 *
 * PARAMETERS:
 *   _account_id - Account ID to get operations for (from hive.accounts_view)
 *   _from_block - Starting block number (inclusive)
 *   _to_block   - Ending block number (inclusive)
 *   _page       - Page number for pagination (1-indexed, NULL for latest)
 *   _body_limit - Maximum size for operation body (-1 for unlimited)
 *   _limit      - Number of results per page
 *
 * RETURNS: hafah_backend.account_operation_history containing:
 *   - total_operations: Exact count of all operations in range
 *   - total_pages: Calculated from total_operations / _limit
 *   - block_range: The effective from/to block range
 *   - operations_result: Array of operation records
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_history_default(
    _account_id INT,
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  _calculate_pages hafah_backend.calculate_pages_return;
  _ops_count INT;
BEGIN

  /*
   * ===================================================================================
   * STEP 1: CALCULATE SEQUENCE RANGE AND TOTAL COUNT
   * ===================================================================================
   * Convert block range to account_op_seq_no range for efficient index usage.
   * account_op_seq_no is a monotonically increasing sequence number per account.
   */
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);

  /*
   * Get total operation count for pagination calculation.
   * First param NULL means no operation type filter.
   * This count query is fast because it uses the account_operations index.
   */
  _ops_count := hafah_backend.get_account_operations_count(NULL, _account_id, _account_range.from_seq, _account_range.to_seq);

  /*
   * Calculate pagination parameters:
   *   - total_pages: CEIL(_ops_count / _limit)
   *   - offset_filter: How many rows to skip from the end
   *   - limit_filter: How many rows to return (may be less on first page)
   */
  _calculate_pages := hafah_backend.calculate_pages(_ops_count, _page, 'desc', _limit);

  /*
   * ===================================================================================
   * CTE: operation_range
   * ===================================================================================
   * WHY: Fetch operation IDs and metadata from account_operations_view first,
   *      then JOIN to get full operation details. This is more efficient than
   *      joining everything at once.
   *
   * JOIN STRATEGY:
   *   - Inner subquery: Filters on indexed account_op_seq_no column
   *   - operations_view: Get operation body and position (INNER JOIN - always exists)
   *   - operation_types: Get is_virtual flag (INNER JOIN - always exists)
   *   - transactions_view: Get transaction hash (LEFT JOIN - virtual ops have no transaction)
   *
   * PAGINATION:
   *   - Offset applied in WHERE: to_seq - offset_filter (faster than OFFSET clause)
   *   - ORDER BY account_op_seq_no DESC ensures newest-first ordering
   *   - LIMIT applied early to reduce rows before joins
   *
   * PERFORMANCE:
   *   - MATERIALIZED forces CTE evaluation before joins
   *   - Subquery pattern allows optimizer to push down predicates
   */
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ov.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,  -- Convert binary hash to hex string
      ov.op_pos,
      ls.op_type_id,
      ov.body,
      hot.is_virtual
    FROM (
      -- Inner query: fetch from account_operations_view with pagination
      SELECT aov.operation_id, aov.op_type_id, aov.block_num
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _account_id
      AND aov.account_op_seq_no >= _account_range.from_seq
      AND aov.account_op_seq_no <= _account_range.to_seq - _calculate_pages.offset_filter  -- Apply offset in WHERE
      ORDER BY aov.account_op_seq_no DESC
      LIMIT _calculate_pages.limit_filter
    ) ls
    JOIN hive.operations_view ov ON ov.id = ls.operation_id        -- Operation body
    JOIN hafd.operation_types hot ON hot.id = ls.op_type_id        -- Virtual flag
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ov.trx_in_block  -- Transaction hash (NULL for virtual)
  ),
  /*
   * ===================================================================================
   * CTE: result_query
   * ===================================================================================
   * WHY: Apply body size filter and fetch block timestamp.
   *
   * BODY FILTER:
   *   operation_body_filter() replaces oversized operation bodies with a placeholder
   *   to prevent response size explosion. Returns composite (body, operation_id).
   *
   * TIMESTAMP:
   *   Join to blocks_view to get created_at timestamp for each operation.
   */
  result_query AS (
    SELECT
      (filtered_operations.composite).body,       -- Potentially truncated body
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,             -- Block timestamp
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block::SMALLINT
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM operation_range ov
      JOIN hive.blocks_view hb ON hb.num = ov.block_num
    ) filtered_operations
  )
  /*
   * FINAL AGGREGATION
   * Collect all rows into an array for the composite return type.
   * ORDER BY ensures descending operation ID order is preserved.
   */
  SELECT array_agg(rows ORDER BY rows.id DESC)
  INTO _result
  FROM (
    SELECT
      s.body,
      s.block_num,
      s.trx_hash,
      s.op_pos,
      s.op_type_id,
      s.created_at,
      s.is_virtual,
      s.id::TEXT,
      s.trx_in_block
    FROM result_query s
  ) rows;

  /*
   * ===================================================================================
   * RETURN COMPOSITE RESULT
   * ===================================================================================
   * COALESCE ensures NULL-safe returns for empty result sets.
   */
  RETURN (
    COALESCE(_ops_count,0),
    COALESCE(_calculate_pages.total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
