SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.ah_get_account_history( in _filter_low BIGINT, in _filter_high BIGINT, in _account VARCHAR, _start BIGINT, _limit BIGINT, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
  _trx_id TEXT,
  _block INT,
  _trx_in_block BIGINT,
  _op_in_trx BIGINT,
  _virtual_op BOOLEAN,
  _timestamp TEXT,
  _value TEXT,
  _operation_id INT
)
AS
$function$
DECLARE
  __resolved_filter SMALLINT[];
  __account_id INT;
  __upper_block_limit INT;
  __use_filter INT;
BEGIN

  PERFORM hafah_backend.validate_limit( _limit, 1000 );
  PERFORM hafah_backend.validate_start_limit( _start, _limit );

  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL)) AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    RETURN QUERY SELECT
      NULL :: TEXT,
      NULL :: INT,
      NULL :: BIGINT,
      NULL :: BIGINT,
      NULL :: BOOLEAN,
      NULL :: TEXT,
      NULL :: TEXT,
      NULL :: INT
    LIMIT 0;
    RETURN;
  END IF;

  SELECT hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high) INTO __resolved_filter;

  IF _include_reversible THEN
    SELECT num from hive.blocks_view order by num desc limit 1 INTO __upper_block_limit;
  ELSE
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;


  IF _include_reversible THEN
    SELECT INTO __account_id ( select id from hive.accounts_view where name = _account );
  ELSE
    SELECT INTO __account_id ( select id from hafd.accounts where name = _account );
  END IF;

  __use_filter := array_length( __resolved_filter, 1 );

  RETURN QUERY
    WITH pre_result AS
    (
      SELECT -- hafah_backend.ah_get_account_history
        (
          CASE
          WHEN ho.trx_in_block < 0 THEN '0000000000000000000000000000000000000000'
          ELSE encode( (SELECT htv.trx_hash FROM hive.transactions_view htv WHERE ho.trx_in_block >= 0 AND ds.block_num = htv.block_num AND ho.trx_in_block = htv.trx_in_block), 'hex')
          END
        ) AS _trx_id,
        ds.block_num AS _block,
        (
          CASE
          WHEN ho.trx_in_block < 0 THEN 4294967295
          ELSE ho.trx_in_block
          END
        ) AS _trx_in_block,
        ho.op_pos::BIGINT AS _op_in_trx,
        hot.is_virtual AS virtual_op,
        (
          CASE
            WHEN _is_legacy_style THEN hive.get_legacy_style_operation(ho.body_binary)::TEXT
            ELSE ho.body :: text
          END
        ) AS _value,
        ds.account_op_seq_no AS _operation_id
      FROM
      (
        WITH accepted_types AS MATERIALIZED
        (
          SELECT ot.id FROM hafd.operation_types ot WHERE __use_filter IS NOT NULL AND ot.id=ANY(__resolved_filter)
        )
        (SELECT hao.operation_id, hao.op_type_id,hao.block_num, hao.account_op_seq_no
        FROM hive.account_operations_view hao
        JOIN accepted_types t ON hao.op_type_id = t.id
        WHERE __use_filter IS NOT NULL AND hao.account_id = __account_id AND hao.account_op_seq_no <= _start AND hao.block_num <= __upper_block_limit
        ORDER BY hao.account_op_seq_no DESC
        LIMIT _limit
        )
        UNION ALL
        (SELECT hao.operation_id, hao.op_type_id,hao.block_num, hao.account_op_seq_no
        FROM hive.account_operations_view hao
        WHERE __use_filter IS NULL AND hao.account_id = __account_id AND hao.account_op_seq_no <= _start AND hao.block_num <= __upper_block_limit
        ORDER BY hao.account_op_seq_no DESC
        LIMIT _limit
        )

      ) ds
      JOIN LATERAL (SELECT hov.body, hov.body_binary, hov.op_pos, hov.trx_in_block FROM hive.operations_view hov WHERE ds.operation_id = hov.id) ho ON TRUE
      JOIN LATERAL (select ot.is_virtual FROM hafd.operation_types ot WHERE ds.op_type_id = ot.id) hot on true
      ORDER BY ds.account_op_seq_no ASC

    )
    SELECT -- hafah_backend.ah_get_account_history
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result.virtual_op,
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS formated_timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM
      pre_result
      JOIN hive.blocks_view hb ON hb.num = pre_result._block
      ORDER BY pre_result._operation_id ASC;

END
$function$
LANGUAGE plpgsql STABLE
SET JIT=OFF
SET join_collapse_limit=16
SET from_collapse_limit=16
SET plan_cache_mode=force_generic_plan
;

RESET ROLE;
