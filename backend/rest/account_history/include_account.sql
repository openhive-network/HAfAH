SET ROLE hafah_owner;

/*
 * ===================================================================================
 * include_account.sql: Account history filtered by single transacting account (include)
 * ===================================================================================
 * Called by: hafah_backend.get_ops_by_account() in backend/rest/account_history/router.sql
 *
 * Used when: participation_mode='include' with exactly ONE account in the filter array
 *
 * STRATEGY:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Filters operations where transacting_account_id EQUALS the specified account.
 * "Transacting account" is the account that initiated/authored the operation.
 *
 * WHY SLIDING WINDOW PAGINATION?
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Unlike default/by_operations, we CANNOT efficiently count total matching operations
 * because the transacting_account_id filter has high selectivity and counting would
 * require scanning many rows.
 *
 * Solution: "Sliding window" approach:
 *   1. Fetch up to (max_pages * page_size) + 1 rows
 *   2. If we get exactly that many, the window is "saturated" (more data exists)
 *   3. Calculate pagination within this batch
 *   4. Return adjusted from_block for cursor-based continuation
 *
 * BLOCK BOUNDARY HANDLING:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Corner case: Last two operations in the batch might be in the same block.
 * If we simply return min_block - 1 as the cursor, the next batch might miss
 * operations from that block.
 *
 * Solution:
 *   1. Check if last 2 ops are in the same block
 *   2. If yes, fetch ALL ops from that block and include them
 *   3. This ensures no operations are lost across batch boundaries
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: account_history_include_account
 * ===================================================================================
 * PURPOSE: Retrieve account operations where the transacting account matches the
 *          specified account (single account scalar comparison for performance).
 *
 * PARAMETERS:
 *   _account_id             - Account ID to get operations for (the "affected" account)
 *   _operations             - Array of operation type IDs to filter by (NULL for all)
 *   _transacting_account_id - Account ID that must be the transacting party (the "author")
 *   _from_block             - Starting block number (inclusive)
 *   _to_block               - Ending block number (inclusive)
 *   _page                   - Page number for pagination (1-indexed, within current batch)
 *   _body_limit             - Maximum size for operation body (-1 for unlimited)
 *   _limit                  - Number of results per page
 *
 * RETURNS: hafah_backend.account_operation_history containing:
 *   - total_operations: Count within current batch (NOT global total)
 *   - total_pages: Pages available in current batch (max 10)
 *   - block_range: Adjusted range - from_block may be decreased for cursor continuation
 *   - operations_result: Array of operation records
 *
 * CURSOR PAGINATION:
 *   Client should use returned from_block as to-block in next request to continue.
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_history_include_account(
    _account_id INT,
    _operations INT [],
    _transacting_account_id INT,
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
-- Plan each call with its account and filter: walking hive_account_operations_uq1
-- is fast when the requested types are common for the account, the
-- (account_id, op_type_id) index is fast when they are rare.
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  -- Maximum pages per batch (sliding window size)
  __max_page_count INT := 10;

  __total_pages INT;
  __min_block_num INT;  -- Lowest block number in result set (for cursor)
  __count INT;          -- Operations in current batch
  __rare_types BOOLEAN;  -- TRUE: read all matches by type and sort, FALSE: walk uq1
BEGIN
  /*
   * ===================================================================================
   * STEP 1: CALCULATE SEQUENCE RANGE
   * ===================================================================================
   * Convert block range to account_op_seq_no range for efficient filtering.
   */
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);

  -- Rare/common page plan, as in account_history_by_operations; [from_seq, to_seq]
  -- already stops at the last irreversible block
  __rare_types := hafah_backend.account_op_types_are_rare(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1
  );

  /*
   * ===================================================================================
   * CTE: operation_range
   * ===================================================================================
   * WHY: Fetch up to (max_pages * limit) + 1 operations matching the include filter.
   *      The +1 is used to detect if the window is saturated.
   *
   * FILTER:
   *   transacting_account_id = _transacting_account_id (scalar comparison)
   *   - Uses equality operator for single account (better index usage than ANY())
   *   - IS NOT NULL check for future compatibility with NULL values
   *
   * ROW_NUMBER():
   *   Assigns sequential numbers to detect saturation and find last 2 rows.
   */
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      -- Row number for saturation detection and block boundary check
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      -- Exactly one branch runs; the custom plan folds the other away
      (
        -- Walk uq1; the fence keeps the sort-everything plan out of this branch
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0  -- Filters stay outside, so the planner costs the walk on every account row
        ) walk
        WHERE walk.transacting_account_id = _transacting_account_id  -- Include filter (scalar)
        AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)  -- Optional type filter
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1  -- +1 to detect saturation
      )
      UNION ALL
      (
        -- Rare types: every match through the (account_id, op_type_id) index, then sort
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
          AND ao.account_id = _account_id
          AND ao.transacting_account_id = _transacting_account_id  -- Include filter (scalar)
          AND ao.op_type_id = ANY(_operations)
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          OFFSET 0  -- Plan the fetch of all matches on its own, not as an ordered walk
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1  -- +1 to detect saturation
      )
    ) ls
  ),
  /*
   * ===================================================================================
   * CTE: check_if_saturated
   * ===================================================================================
   * WHY: Determine if we hit the row limit (window is full).
   *
   * RETURNS:
   *   - count = (max_pages * limit) + 1 if saturated
   *   - NULL if not saturated (less data than window size)
   */
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  /*
   * ===================================================================================
   * CTE: if_saturated_find_last_two_ops
   * ===================================================================================
   * WHY: Get the last two operations to check if they're in the same block.
   *
   * RETURNS: Empty if not saturated. Otherwise, the last 2 rows.
   */
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),      -- Last row
      (SELECT count - 1 FROM check_if_saturated)   -- Second-to-last row
    )
  ),
  /*
   * ===================================================================================
   * CTE: block_check
   * ===================================================================================
   * WHY: Determine if the last 2 operations are in the SAME block.
   *      This is the "block boundary" corner case.
   *
   * RETURNS:
   *   - block_num: The shared block number (if same block), NULL otherwise
   *   - account_op_seq_no: The sequence number of the last op (for re-query)
   *
   * If both ops are in the same block, we need to fetch ALL ops from that block
   * to avoid missing any when the client continues with the cursor.
   */
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  /*
   * ===================================================================================
   * CTE: filter_by_op_seq
   * ===================================================================================
   * WHY: If last 2 ops are in same block, fetch ALL ops from that block.
   *      This query only runs if block_check returned a non-NULL block.
   *
   * RETURNS: Empty if no block boundary issue. Otherwise, all ops in the boundary block.
   */
  filter_by_op_seq AS MATERIALIZED (
    (
      -- Walk uq1; the fence keeps the sort-everything plan out of this branch
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          -- Only execute if block boundary issue detected
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0  -- Filters stay outside, so the planner costs the walk on every account row
      ) walk
      WHERE walk.transacting_account_id = _transacting_account_id
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit  -- Safety limit for the extra records
    )
    UNION ALL
    (
      -- Rare types: every match through the (account_id, op_type_id) index, then sort
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE __rare_types
        AND ao.account_id = _account_id
        AND ao.transacting_account_id = _transacting_account_id
        AND ao.op_type_id = ANY(_operations)
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          -- Only execute if block boundary issue detected
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        OFFSET 0  -- Plan the fetch of all matches on its own, not as an ordered walk
      ) rare
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit  -- Safety limit for the extra records
    )
  ),
  /*
   * ===================================================================================
   * CTE: find_all_records_for_page
   * ===================================================================================
   * WHY: Filter to only include ops from the boundary block.
   *
   * RETURNS: Empty if no block boundary issue. Otherwise, ops from the specific block.
   */
  find_all_records_for_page AS (
    SELECT
      ls.id,
      ls.block_num,
      ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  /*
   * ===================================================================================
   * CTE: union_operations
   * ===================================================================================
   * WHY: Combine the main result set with any additional ops from block boundary.
   *
   * LOGIC:
   *   1. Take operation_range up to (max_pages * limit) rows (excluding the +1 probe row)
   *   2. UNION ALL with find_all_records_for_page (empty if no boundary issue)
   *
   * Note: May result in slightly more than (max_pages * limit) rows if block
   * boundary handling added extra ops. This is intentional.
   */
  union_operations AS MATERIALIZED (
    SELECT
      id,
      block_num,
      op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)  -- Exclude the +1 probe row
    UNION ALL
    SELECT
      id,
      block_num,
      op_type_id
    FROM find_all_records_for_page  -- Empty if no block boundary issue
  ),
  /*
   * ===================================================================================
   * CTE: min_block_num
   * ===================================================================================
   * WHY: Find the lowest block number for cursor calculation.
   */
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  /*
   * ===================================================================================
   * CTE: count_blocks
   * ===================================================================================
   * WHY: Count total operations in the current batch for pagination.
   */
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  /*
   * ===================================================================================
   * CTE: calculate_pages
   * ===================================================================================
   * WHY: Calculate pagination parameters for the current batch.
   */
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  /*
   * ===================================================================================
   * CTE: filter_page
   * ===================================================================================
   * WHY: Apply pagination to get the requested page.
   */
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  /*
   * ===================================================================================
   * CTE: join_tables
   * ===================================================================================
   * WHY: Fetch operation details from related tables.
   *
   * JOIN STRATEGY:
   *   - helper_operations_view: Operation body and virtual flag (INNER JOIN on
   *     the hafd.operations primary key)
   *   - hafd.transactions: Transaction hash (LEFT JOIN)
   *     Virtual operations have no transaction, so this returns NULL for them.
   */
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      -- LIMIT 1: a position holds one transaction (its index is not declared unique)
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  /*
   * ===================================================================================
   * CTE: result_query
   * ===================================================================================
   * WHY: Apply body size filter and fetch block timestamp.
   */
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  /*
   * FINAL SELECT: Collect results and metadata
   */
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
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
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;

  /*
   * ===================================================================================
   * CURSOR CALCULATION
   * ===================================================================================
   * Adjust from_block for cursor-based pagination:
   *
   *   1. __min_block_num IS NULL:
   *      No results found. Keep original from_block (no more data to fetch).
   *
   *   2. __min_block_num = 1:
   *      Reached genesis block. Can't go lower.
   *
   *   3. __count < __max_page_count * _limit:
   *      Window not saturated. All matching ops are in this batch.
   *      Keep original from_block (no continuation needed).
   *
   *   4. Otherwise (saturated):
   *      Return min_block - 1 as cursor for next request.
   *      Client uses this as to-block to continue fetching.
   */
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );

  /*
   * ===================================================================================
   * RETURN COMPOSITE RESULT
   * ===================================================================================
   */
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
