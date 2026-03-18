SET ROLE hafah_owner;

/*
 * ===================================================================================
 * by_operations.sql: Account history filtered by operation types
 * ===================================================================================
 * Called by: hafah_backend.get_ops_by_account() in backend/rest/account_history/router.sql
 *
 * Used when: Operation type filter is provided AND no account (transacting) filter
 *
 * STRATEGY:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Filters operations by op_type_id using the ANY() array operator.
 * Similar to default.sql but adds operation type predicate.
 *
 * DIFFERENCE FROM DEFAULT:
 *   - account_range() receives _operations to potentially narrow the sequence range
 *   - get_account_operations_count() includes operation filter for accurate totals
 *   - Uses OFFSET clause (not WHERE offset) because filtered rows are non-contiguous
 *
 * PAGINATION:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Standard descending pagination with known total count.
 * OFFSET/LIMIT used because operation filter creates gaps in sequence numbers.
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: account_history_by_operations
 * ===================================================================================
 * PURPOSE: Retrieve account operations filtered by operation types. Returns operations
 *          matching any of the specified types within the given block range.
 *
 * PARAMETERS:
 *   _account_id - Account ID to get operations for (from hive.accounts_view)
 *   _operations - Array of operation type IDs to filter by (e.g., [2, 64] for transfer + producer_reward)
 *   _from_block - Starting block number (inclusive)
 *   _to_block   - Ending block number (inclusive)
 *   _page       - Page number for pagination (1-indexed, NULL for latest)
 *   _body_limit - Maximum size for operation body (-1 for unlimited)
 *   _limit      - Number of results per page
 *
 * RETURNS: hafah_backend.account_operation_history containing:
 *   - total_operations: Exact count of operations matching the type filter
 *   - total_pages: Calculated from total_operations / _limit
 *   - block_range: The effective from/to block range
 *   - operations_result: Array of operation records
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_history_by_operations(
    _account_id INT,
    _operations INT [],
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
   * Convert block range to account_op_seq_no range.
   * _operations passed to account_range() for potential optimization.
   */
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);

  /*
   * Get count of operations matching the type filter.
   * This is used for pagination calculation.
   */
  _ops_count := hafah_backend.get_account_operations_count(_operations, _account_id, _account_range.from_seq, _account_range.to_seq);

  /*
   * Calculate pagination parameters with descending order.
   * Unlike default.sql, we must use OFFSET here because filtered results
   * are not contiguous in the sequence.
   */
  _calculate_pages := hafah_backend.calculate_pages(_ops_count, _page, 'desc', _limit);

  /*
   * ===================================================================================
   * CTE: operation_range
   * ===================================================================================
   * WHY: Fetch operations matching the type filter from account_operations_view.
   *
   * OPERATION TYPE FILTER:
   *   Uses op_type_id = ANY(_operations) for array membership check.
   *   Pattern: (_operations IS NULL OR op_type_id = ANY(_operations))
   *   - If _operations is NULL, all types match (no filter)
   *   - Otherwise, only matching types are included
   *
   * JOIN STRATEGY:
   *   - operations_view: Get operation body and position
   *   - operation_types: Get is_virtual flag
   *   - transactions_view: Get transaction hash (LEFT JOIN for virtual ops)
   *
   * PAGINATION:
   *   - Uses LIMIT/OFFSET instead of WHERE clause offset
   *   - OFFSET required because filtered rows are non-contiguous
   *   - ORDER BY account_op_seq_no DESC for newest-first
   */
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      (SELECT trx_in_block FROM hive.operations_view WHERE id = ls.operation_id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS trx_in_block,
      encode((SELECT htv.trx_hash FROM hive.transactions_view htv
              WHERE htv.block_num = ls.block_num
              AND htv.trx_in_block = (SELECT trx_in_block FROM hive.operations_view WHERE id = ls.operation_id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0))
             ), 'hex') AS trx_hash,
      (SELECT op_pos FROM hive.operations_view WHERE id = ls.operation_id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS op_pos,
      ls.op_type_id,
      (SELECT body FROM hive.operations_view WHERE id = ls.operation_id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS body,
      (SELECT is_virtual FROM hafd.operation_types WHERE id = ls.op_type_id) AS is_virtual
    FROM (
      -- Inner query: fetch from account_operations_view with type filter
      SELECT aov.operation_id, aov.op_type_id, aov.block_num
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _account_id
      AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))  -- Operation type filter
      AND aov.account_op_seq_no >= _account_range.from_seq
      AND aov.account_op_seq_no <= _account_range.to_seq
      ORDER BY aov.account_op_seq_no DESC
      LIMIT _calculate_pages.limit_filter
      OFFSET _calculate_pages.offset_filter  -- Must use OFFSET for non-contiguous filtered results
    ) ls
  ),
  /*
   * ===================================================================================
   * CTE: result_query
   * ===================================================================================
   * WHY: Apply body size filter and fetch block timestamp.
   *
   * BODY FILTER:
   *   operation_body_filter() truncates oversized bodies to prevent response explosion.
   *
   * TIMESTAMP:
   *   Join to blocks_view to get created_at for each operation.
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
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM operation_range ov
      JOIN hive.blocks_view hb ON hb.num = ov.block_num
    ) filtered_operations
  )
  /*
   * FINAL AGGREGATION
   * Collect all rows into an array, preserving descending order.
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
