SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.account_history_default(
    _account_id INT,
    _from INT,
    _to INT,
    _body_limit INT,
    _offset INT,
    _limit INT
)
RETURNS SETOF hafah_backend.operation -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
BEGIN
  RETURN QUERY   
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
        AND aov.account_op_seq_no >= _from
        AND aov.account_op_seq_no <= _to - _offset
        ORDER BY aov.account_op_seq_no DESC
        LIMIT _limit
      ) ls
      JOIN hive.operations_view ov ON ov.id = ls.operation_id
      JOIN hafd.operation_types hot ON hot.id = ls.op_type_id
      LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ov.trx_in_block
      )
    -- filter too long operation bodies 
      SELECT 
        (filtered_operations.composite).body,
        filtered_operations.block_num,
        filtered_operations.trx_hash,
        filtered_operations.op_pos,
        filtered_operations.op_type_id,
        filtered_operations.created_at,
        filtered_operations.is_virtual,
        filtered_operations.id::TEXT,
        filtered_operations.trx_in_block::SMALLINT
      FROM (
        SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
        FROM operation_range ov 
        JOIN hive.blocks_view hb ON hb.num = ov.block_num
      ) filtered_operations
      ORDER BY filtered_operations.id DESC;
END
$$;

RESET ROLE;
