SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_block( in _block_num INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
    _trx_id TEXT,
    _trx_in_block BIGINT,
    _op_in_trx BIGINT,
    _virtual_op BOOLEAN,
    _timestamp TEXT,
    _value TEXT,
    _operation_id BIGINT
)
AS
$function$
BEGIN

  IF (NOT _include_reversible) AND _block_num > hive.app_get_irreversible_block() THEN
    RETURN QUERY SELECT
      NULL::TEXT, -- _trx_id
      NULL::BIGINT, -- _trx_in_block
      NULL::BIGINT, -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT, -- _timestamp
      NULL::TEXT, -- _value
      NULL::BIGINT  -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT
      (
        CASE
        WHEN ht.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
        ELSE encode( ht.trx_hash, 'hex')
        END
      ) _trx_id,
      (
        CASE
        WHEN ht.trx_in_block IS NULL THEN 4294967295
        ELSE ht.trx_in_block
        END
      ) _trx_in_block,
      T.op_pos _op_in_trx,
      T.virtual_op _virtual_op,
      trim(both '"' from to_json(hb.created_at)::text) _timestamp,
      (
        CASE
          WHEN _is_legacy_style THEN hive.get_legacy_style_operation(T.body_binary)::text
          ELSE T.body :: text
        END
      ) AS _value,
      T.id::BIGINT _operation_id
    FROM
      (
        --`abs` it's temporary, until position of operation is correctly saved
        SELECT
          ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
        FROM hafah_backend.helper_operations_view ho
        WHERE ho.block_num = _block_num AND ( _only_virtual = FALSE OR ( _only_virtual = TRUE AND ho.virtual_op = TRUE ) )
      ) T
      JOIN hive.blocks_view hb ON hb.num = T.block_num
      LEFT JOIN hive.transactions_view ht ON T.block_num = ht.block_num AND T.trx_in_block = ht.trx_in_block
      ORDER BY _operation_id;
END
$function$
language plpgsql STABLE
SET JIT=OFF;

RESET ROLE;
