-- TODO: add API ERROR from backend.py
-- TODO: parse args from calls
-- TODO: do arg validation

DROP SCHEMA IF EXISTS hafah_api CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api;

CREATE OR REPLACE PROCEDURE hafah_api.create_api_user()
LANGUAGE 'plpgsql'
AS $$
BEGIN
  --recreate role for reading data
  DROP OWNED BY hived;
  DROP ROLE IF EXISTS hived;
  CREATE ROLE hived;

  GRANT USAGE ON SCHEMA hafah_api TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_api TO hived;

  GRANT USAGE ON SCHEMA hafah_python TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_python TO hived;

  GRANT USAGE ON SCHEMA hive TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hived;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hived;

  -- recreate role for connecting to db
  DROP ROLE IF EXISTS haf_admin;
  CREATE ROLE haf_admin NOINHERIT LOGIN PASSWORD 'haf_admin';

  -- add ability for admin to switch to hived role
  GRANT hived TO haf_admin;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.home(jsonrpc TEXT, method TEXT, params JSON, id TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  _jsonrpc TEXT = jsonrpc;
  _method TEXT = method;
  _params JSON = params;
  _id TEXT = id;

  __result JSON;
  __input_assertion JSON;
  __api_type TEXT;
  __method_type TEXT;
  __is_old_schema BOOLEAN;
  __json_type TEXT;
BEGIN
  -- TODO: convert id to int when called without " "
  -- TODO: is json order important in errors and responses?
  -- TODO: fix filters
  SELECT hafah_api.assert_input_json(_jsonrpc, _method, _params, _id) INTO __input_assertion;
  IF __input_assertion IS NOT NULL THEN
    RETURN __input_assertion;
  END IF;

  SELECT substring(method FROM '^[^.]+') INTO __api_type;
  SELECT substring(method FROM '[^.]+$') INTO __method_type;

  SELECT json_typeof(_params) INTO __json_type;
  
  IF __api_type = 'account_history_api' THEN
    __is_old_schema = FALSE;
  ELSEIF __api_type = 'condenser_api' THEN
    __is_old_schema = TRUE;
  END IF;

  IF __method_type = 'get_ops_in_block' THEN
    SELECT '0' INTO __result;
  ELSEIF __method_type = 'enum_virtual_ops' THEN
    SELECT '0' INTO __result;
  ELSEIF __method_type = 'get_transaction' THEN
    SELECT '0' INTO __result;
  ELSEIF __method_type = 'get_account_history' THEN
    SELECT hafah_api.call_get_account_history(_params, _id, __is_old_schema, __json_type) INTO __result;
  END IF;

  IF __result->'error' IS NULL THEN
    RETURN REPLACE(result::TEXT, ' :', ':')
    FROM json_build_object(
      'jsonrpc', '2.0',
      'result', __result,
      'id', id
    ) result;
  ELSE
    RETURN __result;
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.call_get_account_history(_params JSON, _id TEXT, _is_old_schema BOOLEAN, _json_type TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __filter INT;
  __account VARCHAR;
  __start BIGINT = NULL;
  __limit INT = NULL;
  __operation_filter_low INT = NULL;
  __operation_filter_high INT = NULL;
  __include_reversible BOOLEAN = NULL;
BEGIN
  -- Assign function arguments and make assertions
  -- 22P02 errors are handled separately for integers and booleans inside BEGIN EXCEPTION END

  -- Required arguments
  __account = hafah_api.parse_argument(_params, _json_type, 'account', 0);
  IF __account IS NOT NULL THEN
    __account = __account::VARCHAR;
  ELSE
    RETURN hafah_api.raise_missing_arg('account', _id);
  END IF;

  BEGIN
    -- Optional arguments
    __start = hafah_api.parse_argument(_params, _json_type, 'start', 1);
    IF __start IS NOT NULL THEN
      __start = __start::BIGINT;
    ELSE
      __start = -1;
    END IF;
    IF __start < 0 THEN
      __start = '9223372036854775807'::BIGINT;
    END IF;

    __limit = hafah_api.parse_argument(_params, _json_type, 'limit', 2);
    IF __limit IS NOT NULL THEN
      __limit = __limit::INT;
    ELSE
      __limit = 1000;
    END IF;
    IF __limit > 1000 THEN
      RETURN hafah_api.raise_error(-32003, format('Assert Exception:args.limit <= 1000: limit of %s is greater than maxmimum allowed', __limit), NULL, _id, TRUE);
    ELSIF __start < __limit - 1  THEN
      RETURN hafah_api.raise_error(-32003, 'Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)', NULL, _id, TRUE);
    END IF;

    __operation_filter_low = hafah_api.parse_argument(_params, _json_type, 'operation_filter_low', 3);
    IF __operation_filter_low IS NOT NULL THEN
      __operation_filter_low = __operation_filter_low::INT;
    ELSE
      __operation_filter_low = 0;
    END IF;

    __operation_filter_high = hafah_api.parse_argument(_params, _json_type, 'operation_filter_high', 4);
    IF __operation_filter_high IS NOT NULL THEN
      __operation_filter_high = __operation_filter_high::INT;
    ELSE
      __operation_filter_high = 0;
    END IF;

  EXCEPTION 
    WHEN invalid_text_representation THEN
      RETURN hafah_api.raise_error(
        -32000,
        'Parse Error:Couldn''t parse uint64_t',
        NULL, _id, TRUE);
  END;

  BEGIN
    __include_reversible = hafah_api.parse_argument(_params, _json_type, 'include_reversible', 5);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_api.raise_error(
        -32000,
        'Bad Cast:Cannot convert string to bool (only "true" or "false" can be converted)',
        NULL, _id, TRUE);
  END;
  
  __filter = ( __operation_filter_high << 64 ) | __operation_filter_low;
  RETURN hafah_api.get_account_history(__filter, __account, __start, __limit, __include_reversible, _is_old_schema);
END;
$$
;

CREATE OR REPLACE FUNCTION hafah_api.parse_argument(_params JSON, _json_type TEXT, _arg_name TEXT, _arg_number INT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _json_type = 'object' THEN
    _params->>_arg_name
  ELSE
    _params->>_arg_number
  END;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.assert_input_json(_jsonrpc TEXT, _method TEXT, _params JSON, _id TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  IF _method NOT SIMILAR TO
    '(account_history_api|condenser_api)\.(get_ops_in_block|enum_virtual_ops|get_transaction|get_account_history)'
  THEN
    RETURN hafah_api.raise_error(-32601, 'Method not found', _method, _id);
  END IF;

  IF _jsonrpc != '2.0' OR
    _jsonrpc IS NULL OR
    _method IS NULL OR
    _params IS NULL
  THEN
    RETURN hafah_api.raise_error(-32600, 'Invalid JSON-RPC');
  END IF;

  RETURN NULL;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.raise_error(_code INT, _message TEXT, _data TEXT = NULL, _id TEXT = NULL, _no_data BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'jsonrpc', '2.0',
    'error',
    CASE WHEN _no_data IS TRUE THEN 
      json_build_object(
        'code', _code,
        'message', _message
      )
    ELSE
      json_build_object(
        'code', _code,
        'message', _message,
        'data', _data
      )
    END,
    'id', _id
  ) error_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.raise_missing_arg(_arg_name TEXT, _id TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_api.raise_error(-32602, 'Invalid parameters', format('missing a required argument: ''%s''', _arg_name), _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.raise_exception(TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION '%', $1;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.translate_filter(_filter INT, _transform INT = 0)
RETURNS INT[]
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  IF _filter != 0 AND _filter IS NOT NULL THEN
    RETURN array_agg(val + _transform) FROM (
      WITH RECURSIVE cte(i, val) AS (
        VALUES(-1, 0)
      UNION ALL
        SELECT
          i + 1,
          CASE WHEN _filter & (1 << i + 1) != 0 THEN i + 1 END          
        FROM cte 
        WHERE i < 127 
      )
      SELECT i, val FROM cte WHERE val IS NOT NULL AND i != -1 AND val < 10
    ) ints;
  ELSE
    RETURN NULL;
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.set_operation_id(_operation_id BIGINT, __fill_operation_id BOOLEAN)
RETURNS VARCHAR
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN __fill_operation_id IS TRUE THEN
    CASE WHEN _operation_id >= 4294967295 THEN
      '"operation_id": "' || _operation_id || '" ' 
    ELSE
      '"operation_id": ' || _operation_id || ' '
    END
  ELSE 
    '"operation_id": 0'
  END;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.build_api_operation(_trx_id TEXT, _block INT, _trx_in_block BIGINT, _op_in_trx BIGINT, _virtual_op BOOLEAN, _timestamp TEXT, _value TEXT, _operation_id BIGINT, _fill_operation_id BOOLEAN, __is_old_schema BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    '{' ||
    '"trx_id": "' || _trx_id || '", ' ||
    '"block": ' || _block || ', ' ||
    '"trx_in_block": ' || _trx_in_block || ', ' ||
    '"op_in_trx": ' || _op_in_trx || ', ' ||
    '"virtual_op": ' || _virtual_op || ', ' ||
    '"timestamp": "' || _timestamp || '", ' ||
    '"op": ' || _value ||
    CASE WHEN __is_old_schema IS TRUE THEN
      ''
    ELSE
      CASE WHEN _operation_id IS NULL THEN
        hafah_api.raise_exception('_operation_id cannot be NULL')
      ELSE
        ', ' || hafah_api.set_operation_id(_operation_id, _fill_operation_id)
      END
    END
    || '}';
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_reversible BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __fill_operation_id BOOLEAN = FALSE;
  __is_old_schema BOOLEAN = FALSE;
BEGIN
  RETURN CASE WHEN __is_old_schema IS TRUE THEN
    ops
  ELSE
    to_jsonb(result)
  END
  FROM (
    SELECT CASE WHEN ops IS NULL THEN
      '[]'::JSONB
    ELSE
      ops
    END AS ops
    FROM (
      SELECT jsonb_agg(ops::JSONB) AS ops FROM (
        SELECT ops FROM (
          WITH cte AS (
            SELECT
                NULL::TEXT AS ops
            UNION ALL
            SELECT hafah_api.build_api_operation(_trx_id, _block_num, _trx_in_block, _op_in_trx, _virtual_op, _timestamp, _value, _operation_id, __fill_operation_id, __is_old_schema)
            FROM hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible, __is_old_schema)
          )
          SELECT ops FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) is_null
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_account_history(_filter INT, _account VARCHAR, _start BIGINT, _limit INT, _include_reversible BOOLEAN, _is_old_schema BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _is_old_schema IS TRUE THEN
    history
  ELSE
    to_json(result)
  END
  FROM (
    SELECT CASE WHEN history IS NULL THEN
      '[]'::JSON
    ELSE
      history
    END AS history
    FROM (
      SELECT json_agg(history::JSON) AS history FROM (
        SELECT history FROM (
          WITH cte AS (
            SELECT
              NULL::TEXT AS history
            UNION ALL
            SELECT
              '[' || _operation_id || ',' ||
              '{' ||
              '"trx_id": "' || _trx_id || '", ' ||
              '"block": ' || _block || ', ' ||
              '"trx_in_block": ' || _trx_in_block || ', ' ||
              '"op_in_trx": ' || _op_in_trx || ', ' ||
              '"virtual_op": ' || _virtual_op || ', ' ||
              '"timestamp": "' || _timestamp || '", ' ||
              '"op": ' || _value ||
              CASE WHEN _is_old_schema IS TRUE THEN
                ''
              ELSE
                ', ' || '"operation_id": 0'
              END
              || '}' ||
              ']'
            FROM hafah_python.ah_get_account_history(hafah_api.translate_filter(_filter), _account, _start, _limit, _include_reversible, _is_old_schema)
          )
          SELECT history FROM cte
        ) obj
      WHERE history IS NOT NULL
      ) to_arr
    ) is_null
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_transaction(_id TEXT,  _include_reversible BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
 __is_old_schema BOOLEAN = FALSE;
BEGIN
  RETURN obj FROM (
    SELECT CASE WHEN obj IS NULL THEN
      '{
      "block_num": null,
      "expiration": null,
      "extensions": [],
      "operations": [],
      "ref_block_num": null,
      "ref_block_prefix": null,
      "signatures": [],
      "transaction_id": "' || _id || '", ' || '
      "transaction_num": null
      }'
    ELSE
      obj
    END
    FROM (
      SELECT
        '{' ||
        '"ref_block_num": ' || _ref_block_num || ', ' ||
        '"ref_block_prefix": ' || _ref_block_prefix || ', ' ||
        '"expiration": "' || _expiration || '", ' ||
        '"operations": ' ||
        (SELECT json_agg(_value) FROM (
          SELECT _value::JSON
          FROM hafah_python.get_ops_in_transaction(_block_num, _trx_in_block, __is_old_schema)
        ) f_call
        ) || ', ' ||
        '"extensions": [], ' ||
        '"signatures": ' ||
        CASE WHEN _multisig_number >= 1 THEN
          array_to_json(ARRAY(
            SELECT _signature
            UNION ALL
            SELECT * FROM hafah_python.get_multi_signatures_in_transaction(_id::BYTEA)
          ))::TEXT
        ELSE
          '["' || _signature || '"]'
        END
        || ', ' ||
        '"transaction_id": "' || _id || '", ' ||
        '"block_num": ' || _block_num || ', ' ||
        '"transaction_num": ' || _trx_in_block || ' ' ||
        '}'::TEXT AS obj
      FROM hafah_python.get_transaction(_id::BYTEA, _include_reversible)
    ) is_null
  ) to_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.group_by_block(ops JSON, block_n_arr INT[], __irreversible_block INT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN json_agg((SELECT ops_by_block WHERE ops_by_block IS NOT NULL)) FROM (
    WITH cte AS (
      SELECT
        NULL::TEXT AS ops_by_block
      UNION ALL
      SELECT
        '{' ||
        '"block": ' || block_n || ', ' ||
        '"irreversible": ' ||
        CASE WHEN block_n <= __irreversible_block IS TRUE THEN true ELSE false END || ', ' ||
        '"ops": ' ||
        (SELECT json_agg(ops_elements) FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (SELECT ops_elements->>'block')::INT = block_n)
        || ', ' ||
        '"timestamp": "' || 
        (SELECT ops_elements->>'timestamp' FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (SELECT ops_elements->>'block')::INT = block_n LIMIT 1)
        || '" ' ||
        '}'
      FROM unnest(block_n_arr) AS block_n
    )
    SELECT ops_by_block FROM cte
  ) obj;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.do_pagination(_block_range_end INT, _limit INT, _len INT, ops_json JSONB, _fill_operation_id BOOLEAN, _group_by_block BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  DROP TABLE IF EXISTS result;

  IF _len > 0 AND _len = _limit THEN
    CREATE TEMP TABLE result AS SELECT
      CASE WHEN o.block_num IS NULL THEN 0 ELSE
        (CASE WHEN o.block_num >= _block_range_end THEN 0 ELSE o.block_num END)
      END AS next_block_range_begin,
      CASE WHEN o.id IS NULL THEN 0 ELSE
      -- TODO: (SELECT hafah_api.set_operation_id(o.id, _fill_operation_id))
      o.id
      END AS next_operation_begin
    FROM
      hive.operations o
    JOIN hive.operation_types ot ON o.op_type_id = ot.id
    WHERE
      CASE WHEN _group_by_block IS TRUE THEN
        ot.is_virtual = TRUE AND
        o.block_num >= (ops_json->'ops_by_block'->-1->'block')::INT AND
        o.id > (ops_json->'ops_by_block'->-1->'ops'->-1->'operation_id')::BIGINT
      ELSE
        ot.is_virtual = TRUE AND
        o.block_num >= (ops_json->'ops'->-1->>'block')::INT AND
        o.id > (ops_json->'ops'->-1->>'operation_id')::BIGINT
      END
    ORDER BY o.block_num, o.id 
    LIMIT 1;
  ELSE
    CREATE TEMP TABLE result AS SELECT
      _block_range_end AS next_block_range_begin,
      0 AS next_operation_begin;
  END IF;
  
  RETURN (
    SELECT jsonb_set(
      (
        SELECT jsonb_set(ops_json,
        '{next_block_range_begin}',
        to_jsonb((SELECT next_block_range_begin FROM result)))
      ),
    '{next_operation_begin}',
    to_jsonb((SELECT next_operation_begin FROM result)))
  );
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.enum_virtual_ops(_block_range_begin INT, _block_range_end INT, _operation_begin BIGINT = 0, _limit INT = 2147483646, _filter INT = NULL, _include_reversible BOOLEAN = FALSE, _group_by_block BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __fill_operation_id BOOLEAN = TRUE;
  __virtual_op_id_offset INT = (SELECT MIN(id) FROM hive.operation_types WHERE is_virtual = True);
  __irreversible_block INT;
  __is_old_schema BOOLEAN = FALSE;
BEGIN
  IF __is_old_schema IS TRUE THEN
    SELECT raise_exception('not supported');
  END IF;

  IF _block_range_begin > _block_range_end THEN
    SELECT raise_exception('block range must be upward');
  END IF;

  IF _block_range_end - _block_range_begin > 2000 THEN
    SELECT raise_exception('block range distance must be less than or equal to 2000');
  END IF;

  IF _group_by_block IS TRUE THEN
    SELECT hive.app_get_irreversible_block() INTO __irreversible_block;
  END IF;

  RETURN
    (SELECT hafah_api.do_pagination(_block_range_end, _limit, _len, ops_json, __fill_operation_id, _group_by_block))
  FROM (
    SELECT
      jsonb_build_object(
        'ops', CASE WHEN _group_by_block IS TRUE OR ops IS NULL THEN '[]'::JSON ELSE ops END,
        'ops_by_block', CASE WHEN _group_by_block IS FALSE OR ops IS NULL THEN '[]'::JSON ELSE (SELECT hafah_api.group_by_block(ops, block_n_arr, __irreversible_block)) END,
        'next_block_range_begin', 0,
        'next_operation_begin', 0
      ) AS ops_json,
      _len
    FROM (
      SELECT
        json_agg(ops::JSON) AS ops,
        array_agg(DISTINCT block_n) AS block_n_arr,
        CASE WHEN _group_by_block IS FALSE THEN count(ops)::INT ELSE 1 END AS _len
      FROM (
        SELECT ops, block_n FROM (
          WITH cte AS (
            SELECT
              NULL::TEXT AS ops,
              NULL::INT AS block_n
            UNION ALL
            SELECT
              hafah_api.build_api_operation(_trx_id, _block, _trx_in_block, _op_in_trx, _virtual_op, _timestamp, _value, _operation_id, __fill_operation_id),
              _block
            FROM hafah_python.enum_virtual_ops(hafah_api.translate_filter(_filter, __virtual_op_id_offset), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
          )
          SELECT ops, block_n FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) group_b
  ) result;
END
$$
;

/*
VERY SLOW RESPONSES UNDER LOAD, NEEDS INVESTIGATION

CREATE OR REPLACE FUNCTION hafah_api.do_pagination(_block_range_end INT, _limit INT, _len INT, ops_json JSONB, _fill_operation_id BOOLEAN, _group_by_block BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  IF _len > 0 AND _len = _limit THEN
    RETURN
      jsonb_set(ops, '{next_operation_begin}', to_jsonb(next_operation_begin))
    FROM (
      SELECT
        (SELECT jsonb_set(ops_json, '{next_block_range_begin}', to_jsonb(next_block_range_begin))) AS ops,
        next_operation_begin
      FROM (
        SELECT
          (CASE WHEN o.block_num IS NULL THEN 0 ELSE
            (CASE WHEN o.block_num >= _block_range_end THEN 0 ELSE o.block_num END)
          END) AS next_block_range_begin,
          (CASE WHEN o.id IS NULL THEN 0 ELSE
          -- TODO: (SELECT hafah_api.set_operation_id(o.id, _fill_operation_id))
          (SELECT o.id)
          END) AS next_operation_begin
        FROM
          hive.operations o
        JOIN hive.operation_types ot ON o.op_type_id = ot.id
        WHERE
          CASE WHEN _group_by_block IS TRUE THEN
            ot.is_virtual = TRUE AND
            o.block_num >= (ops_json->'ops_by_block'->-1->'block')::INT AND
            o.id > (ops_json->'ops_by_block'->-1->'ops'->-1->'operation_id')::BIGINT
          ELSE
            ot.is_virtual = TRUE AND
            o.block_num >= (ops_json->'ops'->-1->>'block')::INT AND
            o.id > (ops_json->'ops'->-1->>'operation_id')::BIGINT
          END
        ORDER BY o.block_num, o.id 
        LIMIT 1
      ) result
    ) insert_result;
  ELSE
    RETURN
      jsonb_set(ops, '{next_operation_begin}', to_jsonb(0))
    FROM (
      SELECT
        jsonb_set(ops_json, '{next_block_range_begin}', to_jsonb(_block_range_end)) AS ops
      ) insert_result;
  END IF;
END
$$
;
*/