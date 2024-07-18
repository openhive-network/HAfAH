--single block
CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_block_json( in _block_num INT, in _operation_begin BIGINT, in _limit INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
BEGIN
  IF _block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  PERFORM hafah_python.validate_negative_limit( _limit );

  RETURN (
    WITH pre_result AS (
      SELECT
        hp.__block_num AS "block",
        hp._value ::json AS "op",
        hp._op_in_trx AS "op_in_trx",
        hp._timestamp AS "timestamp",
        hp._trx_id AS "trx_id",
        hp._trx_in_block AS "trx_in_block",
        hp._virtual_op AS "virtual_op",
        hp._operation_id AS "operation_id"
      FROM
        hafah_python.get_rest_ops_in_block( _block_num, _block_num + 1, _operation_begin, _limit, _only_virtual, _include_reversible, _is_legacy_style ) AS hp
    ),
    pag AS (
      SELECT
        pre_result.block AS block_num,
        pre_result.operation_id AS id
      FROM pre_result
      WHERE pre_result.operation_id = (SELECT MAX(pre_result.operation_id) FROM pre_result)
      LIMIT 1
    ),
    find_last_op AS (
      SELECT id FROM hive.operations_view where block_num = (SELECT block_num FROM pag) order by id desc limit 1
    )
    SELECT to_jsonb(result) 
    FROM (
      SELECT
        hafah_python.json_stringify_bigint(COALESCE((
          CASE
            WHEN (SELECT id FROM find_last_op) = (SELECT id FROM pag) THEN 0
            ELSE (SELECT id FROM pag)
          END
        ), 0)) AS next_operation_begin,
        (
          SELECT ARRAY(
            SELECT
              CASE
                WHEN _is_legacy_style THEN to_jsonb(res) - 'operation_id'
                ELSE to_jsonb(res)
              END
            FROM (
              SELECT
                s.block,
                s.op,
                s.op_in_trx,
                hafah_python.json_stringify_bigint(s.operation_id) AS "operation_id",
                s.timestamp,
                s.trx_id,
                s.trx_in_block,
                s.virtual_op
              FROM pre_result s
            ) AS res
          )
        ) AS ops
    ) AS result
  );
END
$function$
language plpgsql STABLE;

--block range 
CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_blocks_json( in _block_num INT, in _end_block_num INT, in _operation_begin BIGINT, in _limit INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
BEGIN
  IF _end_block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  PERFORM hafah_python.validate_negative_limit( _limit );
  PERFORM hafah_python.validate_limit( _limit, 150000 );
  PERFORM hafah_python.validate_block_range( _block_num, _end_block_num, 2000 );

  RETURN (
    WITH pre_result AS (
      SELECT
        hp.__block_num AS "block",
        hp._value ::json AS "op",
        hp._op_in_trx AS "op_in_trx",
        hp._timestamp AS "timestamp",
        hp._trx_id AS "trx_id",
        hp._trx_in_block AS "trx_in_block",
        hp._virtual_op AS "virtual_op",
        hp._operation_id AS "operation_id"
      FROM
        hafah_python.get_rest_ops_in_block( _block_num, _end_block_num, _operation_begin, _limit, _only_virtual, _include_reversible, _is_legacy_style ) AS hp
    ),
    pag AS (
      SELECT
        (
          CASE
            WHEN (SELECT COUNT(*) FROM pre_result) = _limit THEN
              pre_result.block
            ELSE
              _end_block_num
          END
        ) AS block_num,
        pre_result.operation_id AS id
      FROM pre_result
      WHERE pre_result.operation_id = (SELECT MAX(pre_result.operation_id) FROM pre_result)
      LIMIT 1
    )
    SELECT to_jsonb(result) 
    FROM (
      SELECT
        COALESCE((SELECT block_num FROM pag), (
          CASE
            WHEN _end_block_num > (SELECT num FROM hive.blocks ORDER BY num DESC LIMIT 1) THEN 0
            ELSE _end_block_num
          END
        )) AS next_block_range_begin,
        hafah_python.json_stringify_bigint(COALESCE((
          CASE
            WHEN (SELECT block_num FROM pag) >= _end_block_num THEN 0
            ELSE (SELECT id FROM pag)
          END
        ), 0)) AS next_operation_begin,
        (
          SELECT ARRAY(
            SELECT
              CASE
                WHEN _is_legacy_style THEN to_jsonb(res) - 'operation_id'
                ELSE to_jsonb(res)
              END
            FROM (
              SELECT
                s.block,
                s.op,
                s.op_in_trx,
                hafah_python.json_stringify_bigint(s.operation_id) AS "operation_id",
                s.timestamp,
                s.trx_id,
                s.trx_in_block,
                s.virtual_op
              FROM pre_result s
            ) AS res
          )
        ) AS ops
    ) AS result
  );
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_block( in _block_num INT, in _end_block_num INT, in _operation_begin BIGINT, in _limit INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
    __block_num INT,
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
      NULL::INT, -- _block_num
      NULL::TEXT, -- _trx_id
      NULL::BIGINT, -- _trx_in_block
      NULL::BIGINT, -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT, -- _timestamp
      NULL::TEXT, -- _value
      NULL::BIGINT  -- _operation_id
    LIMIT 0;
    RETURN;
  ELSEIF (NOT _include_reversible) AND _end_block_num > hive.app_get_irreversible_block() THEN
    _end_block_num := hive.app_get_irreversible_block() + 1;
  END IF;

  RETURN QUERY
    WITH hfm_operations AS (
      SELECT
        T.block_num __block_num,
        (
          CASE
          WHEN T2.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
          ELSE encode( T2.trx_hash, 'hex')
          END
        ) _trx_id,
        (
          CASE
          WHEN T2.trx_in_block IS NULL THEN 4294967295
          ELSE T2.trx_in_block
          END
        ) _trx_in_block,
        T.op_pos _op_in_trx,
        T.virtual_op _virtual_op,
        (
          CASE
            WHEN _is_legacy_style THEN hive.get_legacy_style_operation(T.body_binary)::text
            ELSE T.body :: text
          END
        ) AS _value,
        T.id::BIGINT _operation_id
      FROM
        (
          SELECT
            ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
          FROM hafah_python.helper_operations_view ho
          WHERE 
            (block_num >= _block_num) AND 
            (block_num < _end_block_num) AND
            (_only_virtual = FALSE OR ( _only_virtual = TRUE AND ho.virtual_op = TRUE )) AND
            ( _operation_begin = -1 OR ho.id > _operation_begin )
          ORDER BY ho.id
          LIMIT _limit
        ) T
      LEFT JOIN
        (
          SELECT 
            trx_hash, trx_in_block, block_num 
          FROM hive.transactions_view
          WHERE 
            (block_num >= _block_num) AND 
            (block_num < _end_block_num)
        ) T2 ON T.block_num = T2.block_num AND T.trx_in_block = T2.trx_in_block
      WHERE T.block_num >= _block_num AND T.block_num < _end_block_num
      ORDER BY T.id
      LIMIT _limit
    )
    SELECT
      pre_result.__block_num,
      pre_result._trx_id,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result._virtual_op,
      trim(both '"' from to_json(hb.created_at)::text) _timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM hfm_operations pre_result
    JOIN hive.blocks_view hb ON hb.num = pre_result.__block_num
    WHERE hb.num >= _block_num AND hb.num < _end_block_num
    ORDER BY pre_result._operation_id;
END
$function$
language plpgsql STABLE
SET JIT=OFF;
