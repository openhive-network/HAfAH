/*
ah/api/hafah_api.sql

'hafah_api.home(jsonrpc TEXT, method TEXT, params JSON, id JSON)' sends and receives requests via 'call_some_method()':
  - call_get_ops_in_block
  - call_enum_virtual_ops
  - call_get_transaction
  - call_get_account_history
Inside these functions, arguments are parsed from 'params', their values validated and set or set to default.
Argument value assertions are made during parsing. Unique assertions are defined here, in 'call_some_method()',
while repeated are in ah/api/hafah_backend.sql.

Every 'call_some_method()' function calls corresponding method in 'hafah_objects' schema, which has utilities
for generating object responses.
*/

DROP SCHEMA IF EXISTS hafah_api CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api;

CREATE OR REPLACE FUNCTION hafah_api.home(JSON)
RETURNS JSON
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
  __is_old_schema BOOLEAN;
  __json_type TEXT;
BEGIN
  -- TODO: is json order important in errors and responses?

  __jsonrpc = (__request_data->>'jsonrpc');
  __method = (__request_data->>'method');
  __params = (__request_data->'params');
  __id = (__request_data->'id');

  IF __jsonrpc != '2.0' OR __jsonrpc IS NULL OR __params IS NULL OR __id IS NULL THEN
    RETURN hafah_backend.raise_exception(-32600, 'Invalid JSON-RPC');
  END IF;
  
  SELECT hafah_api.assert_input_json(__jsonrpc, __method, __params, __id) INTO __input_assertion;
  IF __input_assertion IS NOT NULL THEN
    RETURN __input_assertion;
  END IF;

  SELECT substring(__method FROM '^[^.]+') INTO __api_type;
  SELECT substring(__method FROM '[^.]+$') INTO __method_type;

  SELECT json_typeof(__params) INTO __json_type;
  
  IF __api_type = 'account_history_api' THEN
    __is_old_schema = FALSE;
  ELSEIF __api_type = 'condenser_api' THEN
    __is_old_schema = TRUE;
  END IF;
  
  IF __method_type = 'get_ops_in_block' THEN
    SELECT hafah_api.call_get_ops_in_block(__params, __id, __is_old_schema, __json_type) INTO __result;
  ELSEIF __method_type = 'enum_virtual_ops' THEN
    SELECT hafah_api.call_enum_virtual_ops(__params, __id, __is_old_schema, __json_type) INTO __result;
  ELSEIF __method_type = 'get_transaction' THEN
    SELECT hafah_api.call_get_transaction(__params, __id, __is_old_schema, __json_type) INTO __result;
  ELSEIF __method_type = 'get_account_history' THEN
    SELECT hafah_api.call_get_account_history(__params, __id, __is_old_schema, __json_type) INTO __result;
  END IF;

  IF __result->'error' IS NULL THEN
    RETURN REPLACE(result::TEXT, ' :', ':')
    FROM json_build_object(
      'jsonrpc', '2.0',
      'result', __result,
      'id', __id
    ) result;
  ELSE
    RETURN __result;
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.call_get_ops_in_block(_params JSON, _id JSON, _is_old_schema BOOLEAN, _json_type TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __block_num INT = NULL;
  __only_virtual BOOLEAN = NULL;
  __include_reversible BOOLEAN = NULL;
  __fill_operation_id BOOLEAN = FALSE;
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
    __only_virtual = hafah_backend.parse_argument(_params, _json_type, 'only_virtual', 1);
    IF __only_virtual IS NOT NULL THEN
      __only_virtual = __only_virtual::BOOLEAN;
    ELSE
      __only_virtual = FALSE;
    END IF;

    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 2);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;

  RETURN hafah_objects.get_ops_in_block(__block_num, __only_virtual, __include_reversible, __fill_operation_id, _is_old_schema, _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.call_enum_virtual_ops(_params JSON, _id JSON, _is_old_schema BOOLEAN, _json_type TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __block_range_begin INT;
  __block_range_end INT;
  __operation_begin BIGINT = NULL;
  __limit INT = NULL;
  __filter NUMERIC = NULL;
  __include_reversible BOOLEAN = NULL;
  __group_by_block BOOLEAN = NULL;
  
  __max_limit INT = 150000;
  __fill_operation_id BOOLEAN = TRUE;
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

    -- Make arg assertions
    IF __block_range_begin > __block_range_end THEN
      RETURN hafah_backend.raise_exception(-32003, 'Assert Exception:blockRangeEnd > blockRangeBegin: Block range must be upward',  NULL, _id, TRUE);
    END IF;

    IF __block_range_end - __block_range_begin > 2000 THEN
      RETURN hafah_backend.raise_exception(-32003, 'Assert Exception:blockRangeEnd - blockRangeBegin <= block_range_limit: Block range distance must be less than or equal to 2000',  NULL, _id, TRUE);
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
      __limit = __max_limit;
    END IF;

    IF __limit <= 0 THEN
      RETURN hhafah_backend.raise_exception(-32003, format('Assert Exception:limit > 0: limit of %s is lesser or equal 0', __limit),  NULL, _id, TRUE);
    END IF;

    IF __limit > __max_limit THEN
      RETURN hafah_backend.raise_exception(-32003, format('Assert Exception:args.limit <= %s: limit of %s is greater than maxmimum allowed', __max_limit, __limit),  NULL, _id, TRUE);
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_int_exception(_id);
  END;

  BEGIN
    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 5);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

    __group_by_block = hafah_backend.parse_argument(_params, _json_type, 'group_by_block', 6);
    IF __group_by_block IS NOT NULL THEN
      __group_by_block = __group_by_block::BOOLEAN;
    ELSE
      __group_by_block = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;

  IF _is_old_schema IS TRUE THEN
    RETURN hafah_backend.raise_exception(-32602, 'Invalid parameters', 'not supported', _id);
  END IF;
  
  RETURN hafah_objects.enum_virtual_ops(__block_range_begin, __block_range_end, __operation_begin, __limit, __filter, __include_reversible, __group_by_block, __fill_operation_id, _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.call_get_transaction(_params JSON, _id JSON, _is_old_schema BOOLEAN, _json_type TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __id TEXT;
  __include_reversible BOOLEAN = NULL;
BEGIN
  __id = hafah_backend.parse_argument(_params, _json_type, 'id', 0);
  IF __id IS NOT NULL THEN
    __id = __id::TEXT;
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

  RETURN hafah_objects.get_transaction(__id, __include_reversible, _is_old_schema, _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.call_get_account_history(_params JSON, _id JSON, _is_old_schema BOOLEAN, _json_type TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __filter NUMERIC;
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

    IF __start < 0 THEN
      __start = '9223372036854775807'::BIGINT;
    END IF;

    __limit = hafah_backend.parse_argument(_params, _json_type, 'limit', 2);
    IF __limit IS NOT NULL THEN
      __limit = __limit::INT;
    ELSE
      __limit = 1000;
    END IF;
    IF __limit > 1000 THEN
      RETURN hafah_backend.raise_exception(-32003, format('Assert Exception:args.limit <= 1000: limit of %s is greater than maxmimum allowed', __limit), NULL, _id, TRUE);
    ELSIF __start < __limit - 1  THEN
      RETURN hafah_backend.raise_exception(-32003, 'Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)', NULL, _id, TRUE);
    END IF;

    __operation_filter_low = hafah_backend.parse_argument(_params, _json_type, 'operation_filter_low', 3);
    IF __operation_filter_low IS NOT NULL THEN
      __operation_filter_low = __operation_filter_low::INT;
    ELSE
      __operation_filter_low = 0;
    END IF;

    __operation_filter_high = hafah_backend.parse_argument(_params, _json_type, 'operation_filter_high', 4);
    IF __operation_filter_high IS NOT NULL THEN
      __operation_filter_high = __operation_filter_high::INT;
    ELSE
      __operation_filter_high = 0;
    END IF;

  EXCEPTION 
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
  END;

  BEGIN
    __include_reversible = hafah_backend.parse_argument(_params, _json_type, 'include_reversible', 5);
    IF __include_reversible IS NOT NULL THEN
      __include_reversible = __include_reversible::BOOLEAN;
    ELSE
      __include_reversible = FALSE;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_bool_case_exception(_id);
  END;
  
  __filter = hafah_backend.create_filter_numeric(__operation_filter_low, __operation_filter_high);
  RETURN hafah_objects.get_account_history(__filter, __account, __start, __limit, __include_reversible, _is_old_schema);
END;
$$
;

CREATE OR REPLACE FUNCTION hafah_api.assert_input_json(_jsonrpc TEXT, _method TEXT, _params JSON, _id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  IF _method NOT SIMILAR TO
    '(account_history_api|condenser_api)\.(get_ops_in_block|enum_virtual_ops|get_transaction|get_account_history)'
  THEN
    RETURN hafah_backend.raise_exception(-32601, 'Method not found', _method, _id);
  END IF;

  RETURN NULL;
END
$$
;