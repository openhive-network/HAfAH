SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.account_history_exclude_account(
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
AS
$$
DECLARE 
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;

  __total_pages INT;
  __min_block_num INT;
  __count INT;
BEGIN
  -----------PAGING LOGIC----------------
  _account_range := hafah_backend.account_range(_operations, _account_id, _from_block, _to_block);

  -- Fetching operations
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num -- used to determine if last 2 records are in the same block (when page is saturated)
    FROM (
      SELECT aov.operation_id, aov.op_type_id, aov.block_num, aov.account_op_seq_no
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _account_id
      AND aov.transacting_account_id != _transacting_account_id
      AND aov.transacting_account_id IS NOT NULL -- for future compatibility
      AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
      AND aov.account_op_seq_no >= _account_range.from_seq
      AND aov.account_op_seq_no <= _account_range.to_seq
      ORDER BY aov.account_op_seq_no DESC
      LIMIT (__max_page_count * _limit) + 1 -- by default operation filter is limited to 10 pages
      -- The +1 is to check if there are more operations in block that are not included in the current page-range
    ) ls
  ),
  -----------PAGING LOGIC----------------
  -- Calculating pages based on result set (operation_range) 
  -- there is corner case when the last two operations are in the same block
  -- when generating next batch of pages, we may miss operations made in the same block
  -- to prevent this, we check if the last two operations are in the same block
  -- if there at least 2 operations in the same block, we fetch all operations in that block
  -- and add them to the result set
  -- and calculate pages based on the new result set
  check_if_saturated AS ( -- if not saturated, returns empty
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
  if_saturated_find_last_two_ops AS ( -- if not saturated, returns empty
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated), 
      (SELECT count - 1 FROM check_if_saturated)
    )
  ), 
  block_check AS MATERIALIZED ( -- if not saturated, returns empty
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN 
          MIN(block_num)
        ELSE 
          NULL
      END  
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN 
          MIN(account_op_seq_no)
        ELSE 
          NULL
      END  
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  -- returns empty if the last two operations are not in the same block
  -- if the last two operations are in the same block, next CTE returns all operations in that block
  find_all_records_for_page AS ( -- if not saturated, returns empty
    SELECT 
      aov.operation_id AS id, 
      aov.op_type_id,
      aov.block_num
    FROM hive.account_operations_view aov
    WHERE aov.account_id = _account_id
    AND aov.transacting_account_id != _transacting_account_id
    AND aov.transacting_account_id IS NOT NULL -- for future compatibility
    AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
    AND aov.account_op_seq_no >= _account_range.from_seq
    AND (
	    (SELECT account_op_seq_no FROM block_check) IS NOT NULL 
	    AND aov.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
	  ) 
    AND (
	    (SELECT block_num FROM block_check) IS NOT NULL 
	    AND aov.block_num = (SELECT block_num FROM block_check)
	  )
    ORDER BY aov.account_op_seq_no DESC
  ),
  union_operations AS MATERIALIZED (
    SELECT
      id,
      block_num,
      op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit) -- limit to the maximum number of rows for the page and remove the extra row
    -- if block_check is not NULL, exclude the operations from last block
    -- operations from excluded block are fetched in find_all_records_for_page
    UNION ALL

    SELECT
      id,
      block_num,
      op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT 
      MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT 
      COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT 
      total_pages,
      offset_filter,
      limit_filter
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
  -----------END PAGING LOGIC----------------
  -- join the operations with other necessary tables 
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ov.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ov.op_pos,
      ls.op_type_id,
      ov.body,
      hot.is_virtual
    FROM (
      SELECT aov.id, aov.op_type_id, aov.block_num
      FROM filter_page aov
    ) ls
    JOIN hive.operations_view ov ON ov.id = ls.id
    JOIN hafd.operation_types hot ON hot.id = ls.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ov.trx_in_block
  ),
  -- filter too long operation bodies 
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

  -- 1. If the min block number is NULL - the result is empty - there are no results for whole provided range
  -- 2. If the min block number is NOT NULL and pages are not fully saturated it means there is no more blocks to fetch 
  -- 3. (ELSE) If the min block number is NOT NULL - the result is not empty - there are results for the provided range
  -- and the min block number can be used as filter in the next API call (as a to-block parameter)
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );

  ----------------------------------------
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
