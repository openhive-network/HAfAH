SET ROLE hafah_owner;

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

  -----------PAGING LOGIC----------------
  _account_range := hafah_backend.account_range(_operations, _account_id, _from_block, _to_block);

  _ops_count := hafah_backend.get_account_operations_count(_operations, _account_id, _account_range.from_seq, _account_range.to_seq);

  _calculate_pages := hafah_backend.calculate_pages(_ops_count, _page, 'desc', _limit);

  -- Fetching operations
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ov.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ov.op_pos,
      ls.op_type_id,
      ov.body,
      hot.is_virtual
    FROM (
      SELECT aov.operation_id, aov.op_type_id, aov.block_num
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _account_id
      AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
      AND aov.account_op_seq_no >= _account_range.from_seq
      AND aov.account_op_seq_no <= _account_range.to_seq
      ORDER BY aov.account_op_seq_no DESC
      LIMIT _calculate_pages.limit_filter
      OFFSET _calculate_pages.offset_filter
    ) ls
    JOIN hive.operations_view ov ON ov.id = ls.operation_id
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
      FROM operation_range ov 
      JOIN hive.blocks_view hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
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
      s.trx_in_block::SMALLINT
    FROM result_query s
  ) rows;

  ----------------------------------------
  RETURN (
    COALESCE(_ops_count,0),
    COALESCE(_calculate_pages.total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
