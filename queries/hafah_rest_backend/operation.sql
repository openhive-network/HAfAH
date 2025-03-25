SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_operation(
    _operation_id INT
)
RETURNS hafah_backend.operation 
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN (
      ov.body,
      ov.block_num,
      encode(htv.trx_hash, 'hex'),
      ov.op_pos,
      ov.op_type_id,
      ov.timestamp,
      hot.is_virtual,
      ov.id::TEXT,
      ov.trx_in_block
    )::hafah_backend.operation 
    FROM hive.operations_view_extended ov
    JOIN hafd.operation_types hot ON hot.id = ov.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ov.block_num AND htv.trx_in_block = ov.trx_in_block
    WHERE ov.id = _operation_id;
END
$$;

RESET ROLE;
