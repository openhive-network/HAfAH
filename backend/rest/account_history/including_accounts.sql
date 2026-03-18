SET ROLE hafah_owner;

/*
 * ===================================================================================
 * including_accounts.sql: Account history filtered by multiple transacting accounts (include)
 * ===================================================================================
 * Called by: hafah_backend.get_ops_by_account() in backend/rest/account_history/router.sql
 *
 * Used when: participation_mode='include' with MORE THAN ONE account in the filter array
 *
 * DIFFERENCE FROM include_account.sql:
 * ─────────────────────────────────────────────────────────────────────────────────────
 *   - include_account.sql:    transacting_account_id = _id (scalar)
 *   - including_accounts.sql: transacting_account_id = ANY(_ids) (array)
 *
 * Uses the same sliding window pagination strategy as include_account.sql.
 * See that file for detailed documentation of the pagination mechanism.
 *
 * STRATEGY:
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Filters operations where transacting_account_id matches ANY of the specified accounts.
 * Uses = ANY() operator for array membership check.
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: account_history_including_accounts
 * ===================================================================================
 * PURPOSE: Retrieve account operations where the transacting account matches any
 *          of the specified accounts. Uses sliding window pagination with max 10 pages.
 *
 * PARAMETERS:
 *   _account_id              - Account ID to get operations for (the "affected" account)
 *   _operations              - Array of operation type IDs to filter by (NULL for all)
 *   _transacting_account_ids - Array of account IDs that may be the transacting party
 *   _from_block              - Starting block number (inclusive)
 *   _to_block                - Ending block number (inclusive)
 *   _page                    - Page number for pagination (within current batch)
 *   _body_limit              - Maximum size for operation body (-1 for unlimited)
 *   _limit                   - Number of results per page
 *
 * RETURNS: hafah_backend.account_operation_history with cursor-adjusted block range
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_history_including_accounts(
    _account_id INT,
    _operations INT [],
    _transacting_account_ids INT [],
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
  __max_page_count INT := 10;  -- Sliding window size

  __total_pages INT;
  __min_block_num INT;
  __count INT;
BEGIN
  /*
   * STEP 1: Calculate sequence range from block range
   */
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);

  /*
   * ===================================================================================
   * CTE: operation_range
   * ===================================================================================
   * Fetch operations where transacting_account_id matches ANY of the filter accounts.
   *
   * KEY DIFFERENCE: Uses = ANY(_transacting_account_ids) for multi-account matching.
   */
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      SELECT aov.operation_id, aov.op_type_id, aov.block_num, aov.account_op_seq_no
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _account_id
      AND aov.transacting_account_id = ANY(_transacting_account_ids)  -- Multi-account include (array membership)
      AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
      AND aov.account_op_seq_no >= _account_range.from_seq
      AND aov.account_op_seq_no <= _account_range.to_seq
      ORDER BY aov.account_op_seq_no DESC
      LIMIT (__max_page_count * _limit) + 1
    ) ls
  ),
  /*
   * SLIDING WINDOW PAGINATION CTEs
   * (See include_account.sql for detailed documentation)
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
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
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
   * Block boundary handling: fetch all ops from boundary block if needed.
   * Uses same = ANY() filter as operation_range.
   */
  filter_by_op_seq AS MATERIALIZED (
    SELECT
      aov.operation_id AS id,
      aov.op_type_id,
      aov.block_num
    FROM hive.account_operations_view aov
    WHERE aov.account_id = _account_id
    AND aov.transacting_account_id = ANY(_transacting_account_ids)  -- Multi-account include
    AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
    AND aov.account_op_seq_no >= _account_range.from_seq
    AND (
      (SELECT account_op_seq_no FROM block_check) IS NOT NULL
      AND aov.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
    )
    ORDER BY aov.account_op_seq_no DESC
    LIMIT _limit
  ),
  find_all_records_for_page AS (
    SELECT ls.id, ls.block_num, ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT id, block_num, op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT id, block_num, op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  /*
   * JOIN operation details from related tables
   */
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      (SELECT trx_in_block FROM hive.operations_view WHERE id = ls.id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS trx_in_block,
      encode((SELECT htv.trx_hash FROM hive.transactions_view htv
              WHERE htv.block_num = ls.block_num
              AND htv.trx_in_block = (SELECT trx_in_block FROM hive.operations_view WHERE id = ls.id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0))
             ), 'hex') AS trx_hash,
      (SELECT op_pos FROM hive.operations_view WHERE id = ls.id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS op_pos,
      ls.op_type_id,
      (SELECT body FROM hive.operations_view WHERE id = ls.id
       AND id >= hafd.operation_id(ls.block_num, 0) AND id < hafd.operation_id(ls.block_num + 1, 0)) AS body,
      (SELECT is_virtual FROM hafd.operation_types WHERE id = ls.op_type_id) AS is_virtual
    FROM (
      SELECT aov.id, aov.op_type_id, aov.block_num
      FROM filter_page aov
    ) ls
  ),
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
      JOIN hive.blocks_view hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
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
   * CURSOR CALCULATION
   * Adjust from_block for next API call continuation.
   * (See include_account.sql for detailed documentation)
   */
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );

  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
