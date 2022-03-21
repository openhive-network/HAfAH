/*
ah/api/hafah_endpoints.sql

'hafah_endpoints.home(jsonrpc TEXT, method TEXT, params JSON, id JSON)' sends and receives requests via 'some_method()':
  - get_ops_in_block
  - enum_virtual_ops
  - get_transaction
  - get_account_history
Inside these functions, arguments are parsed from 'params', their values validated and set or set to default.
Argument value assertions are made during parsing. Unique assertions are defined here, in 'some_method()',
while repeated are in ah/api/hafah_backend.sql.

Every 'some_method()' function calls corresponding method in 'hafah_objects' schema, which has utilities
for generating object responses.
*/
DROP SCHEMA IF EXISTS hafah_endpoints CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_endpoints;

CREATE FUNCTION hafah_endpoints.home(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __request_data JSON = $1;
  __jsonrpc TEXT;
  __method TEXT;
  __params JSON;
  __id JSON;

  __result JSON;
  __input_assertion JSON;
  __api_type TEXT;
  __method_type TEXT;
  __is_legacy_style BOOLEAN;
  __json_type TEXT;
BEGIN
  __jsonrpc = (__request_data->>'jsonrpc');
  __method = (__request_data->>'method');
  __params = (__request_data->'params');
  __id = (__request_data->'id');

  IF __jsonrpc != '2.0' OR __jsonrpc IS NULL OR __params IS NULL OR __id IS NULL THEN
    RETURN hafah_backend.raise_exception(-32600, 'Invalid JSON-RPC');
  END IF;
  
  SELECT hafah_backend.assert_input_json(__jsonrpc, __method, __params, __id) INTO __input_assertion;
  IF __input_assertion IS NOT NULL THEN
    RETURN __input_assertion;
  END IF;

  SELECT substring(__method FROM '^[^.]+') INTO __api_type;
  SELECT substring(__method FROM '[^.]+$') INTO __method_type;

  SELECT json_typeof(__params) INTO __json_type;
  
  IF __api_type = 'account_history_api' THEN
    __is_legacy_style = FALSE;
  ELSEIF __api_type = 'condenser_api' THEN
    __is_legacy_style = TRUE;
  END IF;
  
  IF __method_type = 'get_ops_in_block' THEN
    SELECT hafah_endpoints.get_ops_in_block(__params, __is_legacy_style, __id, __json_type) INTO __result;
  ELSEIF __method_type = 'enum_virtual_ops' THEN
    SELECT hafah_endpoints.enum_virtual_ops(__params, __is_legacy_style, __id, __json_type) INTO __result;
  ELSEIF __method_type = 'get_transaction' THEN
    SELECT hafah_endpoints.get_transaction(__params, __is_legacy_style, __id, __json_type) INTO __result;
  ELSEIF __method_type = 'get_account_history' THEN
    SELECT hafah_endpoints.get_account_history(__params, __is_legacy_style, __id, __json_type) INTO __result;
  END IF;

  IF __result->'error' IS NULL THEN
    SELECT jsonb_build_object(
      'jsonrpc', '2.0',
      'result', __result,
      'id', __id
    ) INTO __result;
  END IF;

  --PERFORM set_config('response.headers', format('[{"Content-Length": "%s"}]', length(__result::TEXT)), TRUE);

  RETURN __result;
END
$$
;

CREATE FUNCTION hafah_endpoints.get_ops_in_block(_params JSON, _is_legacy_style BOOLEAN, _id JSON = NULL, _json_type TEXT = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __block_num INT = NULL; -- default 0
  __only_virtual BOOLEAN = NULL; -- default FALSE
  __include_reversible BOOLEAN = NULL; -- default FALSE

  __result JSON;
  __exception_message TEXT;
BEGIN
  BEGIN
    __block_num = hafah_backend.parse_argument(_params, _json_type, 'block_num', 0);
    IF __block_num IS NOT NULL THEN
      __block_num = __block_num::INT;
    ELSE
      __block_num = 0;
    END IF;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
  END;

  BEGIN
    __only_virtual = hafah_backend.parse_argument(_params, _json_type, 'only_virtual', 1, TRUE);
    IF __only_virtual IS NOT NULL THEN
      __only_virtual = __only_virtual::BOOLEAN;
    ELSE
      __only_virtual = FALSE;
    END IF;

    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 2, TRUE);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;

  BEGIN
    SELECT hafah_python.get_ops_in_block_json(__block_num, __only_virtual, __include_reversible, _is_legacy_style) INTO __result;
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      IF __exception_message ~ 'op_id cannot be None' THEN
        SELECT hafah_backend.raise_operation_id_exception(_id) INTO __result;
      END IF;
  END;

  RETURN __result;
END
$$
;

CREATE FUNCTION hafah_endpoints.enum_virtual_ops(_params JSON, _is_legacy_style BOOLEAN, _id JSON = NULL, _json_type TEXT = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __block_range_begin INT; -- required
  __block_range_end INT; -- required
  __operation_begin BIGINT = NULL; -- default 0
  __limit INT = NULL; -- default 150000
  __filter NUMERIC = NULL; -- default NULL
  __include_reversible BOOLEAN = NULL; -- default FALSE
  __group_by_block BOOLEAN = NULL; -- default FALSE
  
  __exception_message TEXT;
  __result JSON;
BEGIN
  BEGIN
    -- Required arguments
    __block_range_begin = hafah_backend.parse_argument(_params, _json_type, 'block_range_begin', 0);
    IF __block_range_begin IS NOT NULL THEN
      __block_range_begin = __block_range_begin::INT;
    ELSE
      RETURN hafah_backend.raise_missing_arg('block_range_begin', _id);
    END IF;

    __block_range_end = hafah_backend.parse_argument(_params, _json_type, 'block_range_end', 1);
    IF __block_range_end IS NOT NULL THEN
      __block_range_end = __block_range_end::INT;
    ELSE
      RETURN hafah_backend.raise_missing_arg('block_range_end', _id);
    END IF;

    -- Optional arguments
    __operation_begin = hafah_backend.parse_argument(_params, _json_type, 'operation_begin', 2);
    IF __operation_begin IS NOT NULL THEN
      __operation_begin = __operation_begin::BIGINT;
    ELSE
      __operation_begin = 0;
    END IF;

    __filter = hafah_backend.parse_argument(_params, _json_type, 'filter', 4);
    IF __filter IS NOT NULL THEN
      __filter = __filter::NUMERIC;
    ELSE
      __filter = NULL;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
  END;

  BEGIN
    -- 'limit' is parsed separately because of different exception (uint64_t vs int64_t)
    __limit = hafah_backend.parse_argument(_params, _json_type, 'limit', 3);
    IF __limit IS NOT NULL THEN
      __limit = __limit::INT;
    ELSE
      __limit = 150000;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_int_exception(_id);
  END;

  BEGIN
    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 5, TRUE);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

    __group_by_block = hafah_backend.parse_argument(_params, _json_type, 'group_by_block', 6, TRUE);
    IF __group_by_block IS NOT NULL THEN
      __group_by_block = __group_by_block::BOOLEAN;
    ELSE
      __group_by_block = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;

  BEGIN
    SELECT hafah_python.enum_virtual_ops_json(
      hafah_backend.translate_filter(
        __filter,
        hafah_backend.get_virtual_op_offset() ),
      __block_range_begin, __block_range_end, __operation_begin, __limit, __include_reversible, __group_by_block) INTO __result;
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      IF __exception_message ~ 'op_id cannot be None' THEN
        SELECT hafah_backend.raise_operation_id_exception(_id) INTO __result;
      ELSE
        SELECT hafah_backend.wrap_sql_exception(__exception_message, _id) INTO __result;
      END IF;
  END;

  -- TODO: might do this before calling hafah_objects.enum_virtual_ops(), only done to replicate HAfAH python
  IF _is_legacy_style IS TRUE THEN
    RETURN hafah_backend.raise_exception(-32601, 'Method not found', 'condenser_api.enum_virtual_ops', _id);
  ELSE
    RETURN __result;
  END IF;
END
$$
;

CREATE FUNCTION hafah_endpoints.get_transaction(_params JSON, _is_legacy_style BOOLEAN, _id JSON = NULL, _json_type TEXT = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __id BYTEA; -- required
  __include_reversible BOOLEAN = NULL; -- default FALSE

  __exception_message TEXT;
BEGIN
  __id = hafah_backend.parse_argument(_params, _json_type, 'id', 0);
  IF __id IS NOT NULL THEN
    __id = __id::BYTEA;
  ELSE
    RETURN hafah_backend.raise_missing_arg('id', _id);
  END IF;

  BEGIN
    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 1);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;

  BEGIN
    RETURN hafah_python.get_transaction_json(__id, __include_reversible, _is_legacy_style);
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END
$$
;

CREATE FUNCTION hafah_endpoints.get_account_history(_params JSON, _is_legacy_style BOOLEAN, _id JSON = NULL, _json_type TEXT = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __filter NUMERIC; -- assigned with hafah_backend.create_filter_numeric()
  __account VARCHAR; -- required
  __start BIGINT = NULL; -- default -1
  __limit BIGINT = NULL; -- default 1000
  __operation_filter_low NUMERIC = NULL; -- default 0
  __operation_filter_high NUMERIC = NULL; -- default 0
  __include_reversible BOOLEAN = NULL; -- default FALSE

  __exception_message TEXT;
BEGIN
  -- Assign function arguments and make assertions
  -- 22P02 errors are handled separately for integers and booleans inside BEGIN EXCEPTION END

  -- Required arguments
  __account = hafah_backend.parse_argument(_params, _json_type, 'account', 0);
  IF __account IS NOT NULL THEN
    __account = __account::VARCHAR;
  ELSE
    RETURN hafah_backend.raise_missing_arg('account', _id);
  END IF;

  BEGIN
    -- Optional arguments
    __start = hafah_backend.parse_argument(_params, _json_type, 'start', 1);
    IF __start IS NOT NULL THEN
      __start = __start::BIGINT;
    ELSE
      __start = -1;
    END IF;

    __limit = hafah_backend.parse_argument(_params, _json_type, 'limit', 2);
    IF __limit IS NOT NULL THEN
      __limit = __limit::BIGINT;
    ELSE
      __limit = 1000;
    END IF;

    IF __limit < 0 THEN
      RETURN hafah_backend.raise_below_zero_acc_hist(_id);
    END IF;

    __operation_filter_low = hafah_backend.parse_argument(_params, _json_type, 'operation_filter_low', 3);
    IF __operation_filter_low IS NOT NULL THEN
      __operation_filter_low = __operation_filter_low::NUMERIC;
    ELSE
      __operation_filter_low = 0;
    END IF;

    __operation_filter_high = hafah_backend.parse_argument(_params, _json_type, 'operation_filter_high', 4);
    IF __operation_filter_high IS NOT NULL THEN
      __operation_filter_high = __operation_filter_high::NUMERIC;
    ELSE
      __operation_filter_high = 0;
    END IF;

  EXCEPTION 
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
  END;

  BEGIN
    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 5, TRUE);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;
  
  BEGIN
    RETURN hafah_python.ah_get_account_history_json(
      hafah_backend.translate_filter(
        hafah_backend.create_filter_numeric(__operation_filter_low, __operation_filter_high)
      ),
      __account,
      hafah_backend.parse_acc_hist_start(__start),
      hafah_backend.parse_acc_hist_limit(__limit),
      __include_reversible,
      _is_legacy_style
    );
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END;
$$
;