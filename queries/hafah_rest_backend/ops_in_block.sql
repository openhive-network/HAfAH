SET ROLE hafah_owner;

--single block
CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_block_json(
    in _block_num INT,
    in _operation_types BOOLEAN,
    in _operation_filter_low BIGINT, 
    in _operation_filter_high BIGINT,
    in _operation_begin BIGINT,
    in _limit INT,
    in _include_reversible BOOLEAN,
    in _is_legacy_style BOOLEAN 
)
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
        hafah_python.get_rest_ops_in_block( 
          _block_num,
          _block_num + 1,
          _operation_types,
          _operation_filter_low,
          _operation_filter_high,
          _operation_begin,
          _limit,
          _include_reversible,
          _is_legacy_style
        ) AS hp
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
CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_blocks_json(
    in _block_num INT,
    in _end_block_num INT, 
    in _operation_group_types BOOLEAN,
    in _operation_types INT[],
    in _operation_begin BIGINT,
    in _limit INT,
    in _include_reversible BOOLEAN,
    in _is_legacy_style BOOLEAN 
)
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
  PERFORM hafah_python.validate_block_range( _block_num, _end_block_num + 1, 2001);

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
        hafah_python.get_rest_ops_in_block( 
          _block_num,
          _end_block_num + 1,
          _operation_group_types,
          _operation_types,
          _operation_begin,
          _limit,
          _include_reversible,
          _is_legacy_style
        ) AS hp
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


CREATE OR REPLACE FUNCTION hafah_python.get_rest_ops_in_block( 
    in _block_num INT,
    in _end_block_num INT, 
    in _operation_group_types BOOLEAN,
    in _operation_types INT[], 
    in _operation_begin BIGINT,
    in _limit INT,
    in _include_reversible BOOLEAN,
    in _is_legacy_style BOOLEAN 
)
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
DECLARE
  __operation_filter BOOLEAN = (_operation_group_types IS NULL);
  __resolved_filter_exists BOOLEAN;
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

  __resolved_filter_exists := array_length( _operation_types, 1 ) IS NOT NULL;

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
          WITH accepted_types AS MATERIALIZED
          (
            SELECT ot.id FROM hive.operation_types ot WHERE __resolved_filter_exists AND ot.id=ANY(_operation_types)
          )
          (
            SELECT
              ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
            FROM hafah_python.helper_operations_view ho
            JOIN accepted_types t ON ho.op_type_id = t.id
            WHERE __resolved_filter_exists AND (
                (block_num >= _block_num) AND 
                (block_num < _end_block_num ) AND
                ( _operation_begin = -1 OR ho.id > _operation_begin )
            )
            ORDER BY ho.id
            LIMIT _limit
          )
          UNION ALL
          (
            SELECT
              ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
            FROM hafah_python.helper_operations_view ho
            WHERE NOT __resolved_filter_exists AND (
                (block_num >= _block_num) AND 
                (block_num < _end_block_num ) AND
                (__operation_filter OR (ho.virtual_op = _operation_group_types)) AND
                ( _operation_begin = -1 OR ho.id > _operation_begin )
              )
            ORDER BY ho.id
            LIMIT _limit
          )
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

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_block(
    _block_num INT,
    _page_num INT,
    _page_size INT,
    _filter INT [],
    _order_is hafah_backend.sort_direction, -- noqa: LT01, CP05
    _body_limit INT,
    _account TEXT,
    _key_content TEXT [],
    _setof_keys JSON
)
RETURNS SETOF hafah_backend.operation -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __no_ops_filter BOOLEAN = (_filter IS NULL);
  _offset INT := (_page_num - 1) * _page_size;
  _first_key BOOLEAN = (_key_content[1] IS NULL);
  _second_key BOOLEAN = (_key_content[2] IS NULL);
  _third_key BOOLEAN = (_key_content[3] IS NULL);
BEGIN

IF _account IS NULL THEN
  RETURN QUERY 
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.id,
      ls.block_num,
      ls.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ls.op_pos,
      ls.op_type_id,
      ls.body,
      hot.is_virtual
    FROM (
      With operations_in_block AS 
      (
      SELECT ov.id, ov.trx_in_block, ov.op_pos, ov.body, ov.op_type_id, ov.block_num
      FROM hive.operations_view ov
      WHERE
        ov.block_num = _block_num 
      ),
      filter_ops AS MATERIALIZED 
      (
      SELECT *
      FROM operations_in_block oib 
      WHERE 
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
      )
      SELECT * FROM filter_ops fo
      ORDER BY
        (CASE WHEN _order_is = 'desc' THEN fo.id ELSE NULL END) DESC,
        (CASE WHEN _order_is = 'asc' THEN fo.id ELSE NULL END) ASC
      LIMIT _page_size
      OFFSET _offset
    ) ls
    JOIN hive.operation_types hot ON hot.id = ls.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ls.trx_in_block
    ORDER BY
      (CASE WHEN _order_is = 'desc' THEN ls.id ELSE NULL END) DESC,
      (CASE WHEN _order_is = 'asc' THEN ls.id ELSE NULL END) ASC)

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
    SELECT hafah_backend.operation_body_filter(opr.body, opr.id, _body_limit) as composite, opr.id, opr.block_num, opr.trx_in_block, opr.trx_hash, opr.op_pos, opr.op_type_id, opr.is_virtual, hb.created_at
    FROM operation_range opr
    JOIN hive.blocks_view hb ON hb.num = opr.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id, filtered_operations.trx_in_block, filtered_operations.op_pos;

ELSE

  RETURN QUERY 
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.id,
      ls.block_num,
      ls.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ls.op_pos,
      ls.op_type_id,
      ls.body,
      hot.is_virtual
    FROM (
      WITH account_operations_in_block AS 
      (
        SELECT aov.operation_id
        FROM hive.account_operations_view aov
        WHERE
          aov.account_id = (SELECT av.id FROM hive.accounts_view av WHERE av.name = _account ) AND
          aov.block_num = _block_num 
      ),
      operations_in_block AS 
      (
        SELECT ov.id, ov.trx_in_block, ov.op_pos, ov.body, ov.op_type_id, ov.block_num
        FROM hive.operations_view ov
        JOIN account_operations_in_block aoib ON aoib.operation_id = ov.id
      ),
      filter_ops AS MATERIALIZED 
      (
        SELECT *
        FROM operations_in_block oib 
        WHERE 
          (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
          (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
          (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
          (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
      )
      SELECT * FROM filter_ops fo
      ORDER BY
        (CASE WHEN _order_is = 'desc' THEN fo.id ELSE NULL END) DESC,
        (CASE WHEN _order_is = 'asc' THEN fo.id ELSE NULL END) ASC
      LIMIT _page_size
      OFFSET _offset
    ) ls
    JOIN hive.operation_types hot ON hot.id = ls.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ls.trx_in_block
    ORDER BY
      (CASE WHEN _order_is = 'desc' THEN ls.id ELSE NULL END) DESC,
      (CASE WHEN _order_is = 'asc' THEN ls.id ELSE NULL END) ASC)

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
    SELECT hafah_backend.operation_body_filter(opr.body, opr.id, _body_limit) as composite, opr.id, opr.block_num, opr.trx_in_block, opr.trx_hash, opr.op_pos, opr.op_type_id, opr.is_virtual, hb.created_at
    FROM operation_range opr
    JOIN hive.blocks_view hb ON hb.num = opr.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id, filtered_operations.trx_in_block, filtered_operations.op_pos;

END IF;

END
$$;


CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_block_count(
    _block_num INT,
    _filter INT [],
    _account TEXT,
    _key_content TEXT [],
    _setof_keys JSON
)
RETURNS INT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __no_ops_filter BOOLEAN = (_filter IS NULL);
  _first_key BOOLEAN = (_key_content[1] IS NULL);
  _second_key BOOLEAN = (_key_content[2] IS NULL);
  _third_key BOOLEAN = (_key_content[3] IS NULL);
BEGIN

IF _account IS NULL THEN
  RETURN (
    WITH operations_in_block AS 
    (
      SELECT ov.op_type_id, ov.body
      FROM hive.operations_view ov
      WHERE
        ov.block_num = _block_num 
    ),
    filter_ops AS MATERIALIZED 
    (
      SELECT oib.op_type_id 
      FROM operations_in_block oib 
      WHERE 
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
    )
    SELECT COUNT(*) FROM filter_ops);
ELSE
  RETURN (
    WITH account_operations_in_block AS 
    (
      SELECT aov.operation_id
      FROM hive.account_operations_view aov
      WHERE
        aov.account_id = (SELECT av.id FROM hive.accounts_view av WHERE av.name = _account ) AND
        aov.block_num = _block_num 
    ),
    operations_in_block AS 
    (
      SELECT ov.op_type_id, ov.body
      FROM hive.operations_view ov
      JOIN account_operations_in_block aoib ON aoib.operation_id = ov.id
    ),
    filter_ops AS MATERIALIZED 
    (
      SELECT oib.op_type_id 
      FROM operations_in_block oib 
      WHERE 
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
    )
    SELECT COUNT(*) FROM filter_ops);

END IF;

END
$$;

RESET ROLE;