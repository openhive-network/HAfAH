/*
 * home: JSON-RPC 2.0 dispatcher function.
 *
 * PURPOSE: Routes incoming JSON-RPC requests to appropriate method handlers.
 *
 * SUPPORTED METHODS:
 *   account_history_api:
 *     - get_account_history (account operation history)
 *     - get_ops_in_block (operations in a block)
 *     - enum_virtual_ops (virtual operations in block range)
 *     - get_transaction (transaction by hash)
 *   block_api:
 *     - get_block (full block with transactions)
 *     - get_block_header (block header only)
 *     - get_block_range (multiple blocks)
 *   hive_api:
 *     - get_version (API version info)
 *
 * LEGACY SUPPORT: Also handles condenser_api.* methods for backwards compatibility.
 *                 Legacy style returns slightly different response format (no operation_id).
 *
 * ERROR HANDLING: Returns JSON-RPC error responses:
 *   -32600: Invalid JSON-RPC (missing jsonrpc, params, or id)
 *   -32601: Method not found
 *   -32602: Invalid params (type errors, missing required params)
 *
 * TWO CALL STYLES:
 *   Old style (JSON-RPC envelope):
 *     POST / with {"jsonrpc": "2.0", "method": "account_history_api.get_transaction", "params": {...}, "id": 0}
 *   New style (direct PostgREST RPC):
 *     POST /rpc/get_transaction with {...params}
 *
 * ARCHITECTURE:
 *   home() -> parses method string -> routes to call_* wrapper -> calls backend formatter
 *
 * Note: Schema creation is handled by db/hafah_app.sql
 */

SET ROLE hafah_owner;

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
  __api_type TEXT;
  __method_type TEXT;
  __is_legacy_style BOOLEAN;
  __json_type TEXT;
BEGIN
  __jsonrpc = (__request_data->>'jsonrpc');
  __method = (__request_data->>'method');
  __params = (__request_data->'params');
  __id = (__request_data->'id');

  SELECT NULL::JSON INTO __result;

  IF __jsonrpc != '2.0' OR __jsonrpc IS NULL OR __params IS NULL OR __id IS NULL THEN
    RETURN hafah_backend.raise_exception(-32600, 'Invalid JSON-RPC');
  END IF;

  IF __method = 'hive_api.get_version' THEN
    SELECT hafah_endpoints.get_version() INTO __result;
  ELSE

    SELECT substring(__method FROM '^[^.]+') INTO __api_type;
    SELECT substring(__method FROM '[^.]+$') INTO __method_type;
    SELECT json_typeof(__params) INTO __json_type;

    SELECT CASE WHEN __api_type != 'condenser_api' THEN FALSE ELSE TRUE END INTO __is_legacy_style;

    IF __api_type = 'account_history_api' OR __api_type = 'condenser_api' THEN
      IF __method_type = 'get_ops_in_block' THEN
        SELECT hafah_endpoints.call_get_ops_in_block(__params, __json_type, __is_legacy_style, __id) INTO __result;
      ELSEIF __method_type = 'enum_virtual_ops' AND NOT __is_legacy_style THEN
        SELECT hafah_endpoints.call_enum_virtual_ops(__params, __json_type, __is_legacy_style, __id) INTO __result;
      ELSEIF __method_type = 'get_transaction' THEN
        SELECT hafah_endpoints.call_get_transaction(__params, __json_type, __is_legacy_style, __id) INTO __result;
      ELSEIF __method_type = 'get_account_history' THEN
        SELECT hafah_endpoints.call_get_account_history(__params, __json_type, __is_legacy_style, __id) INTO __result;
      END IF;
    ELSEIF __api_type = 'block_api' THEN
      IF __method_type = 'get_block' THEN
        SELECT hafah_endpoints.call_get_block( __params, __json_type, __id) INTO __result;
      ELSEIF __method_type = 'get_block_header' THEN
        SELECT hafah_endpoints.call_get_block_header( __params, __json_type, __id) INTO __result;
      ELSEIF __method_type = 'get_block_range' THEN
        SELECT hafah_endpoints.call_get_block_range( __params, __json_type, __id) INTO __result;
      END IF;
    END IF;
  END IF;

  IF __result IS NULL THEN
    RETURN hafah_backend.raise_exception(-32601, 'Method not found', __method, __id);
  ELSEIF __result->'error' IS NULL THEN
    RETURN jsonb_build_object(
      'jsonrpc', '2.0',
      'result', __result,
      'id', __id
    );
  ELSE
    RETURN __result::JSONB;
  END IF;
END
$$
;

/*
 * call_get_ops_in_block: JSON-RPC wrapper for get_ops_in_block method.
 *
 * PARAMETERS (from JSON-RPC params):
 *   block_num (INT) - Block number to query (default: 0)
 *   only_virtual (BOOLEAN) - Return only virtual operations (default: FALSE)
 *   include_reversible (BOOLEAN) - Include reversible blocks (default: FALSE)
 *
 * PARAMETER STYLES: Supports both object {"block_num": 123} and array [123] params.
 *
 * DELEGATES TO: hafah_backend.get_ops_in_block_json()
 */
CREATE FUNCTION hafah_endpoints.call_get_ops_in_block(_params JSON, _json_type TEXT, _is_legacy_style BOOLEAN = FALSE, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __block_num INT = NULL; -- default 0
  __only_virtual BOOLEAN = NULL; -- default FALSE
  __include_reversible BOOLEAN = NULL; -- default FALSE

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
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
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
    RETURN hafah_backend.get_ops_in_block_json(__block_num, __only_virtual, __include_reversible, _is_legacy_style);
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      IF __exception_message ~ 'op_id cannot be None' THEN
        RETURN hafah_backend.raise_operation_id_exception(_id);
      ELSE
        RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
      END IF;
  END;
END
$$
;

/*
 * call_enum_virtual_ops: JSON-RPC wrapper for enum_virtual_ops method.
 *
 * PURPOSE: Enumerate virtual operations within a block range.
 *
 * PARAMETERS (from JSON-RPC params):
 *   block_range_begin (INT) - Start block number [REQUIRED]
 *   block_range_end (INT) - End block number [REQUIRED]
 *   operation_begin (BIGINT) - Starting operation ID for pagination (default: 0)
 *   limit (INT) - Max operations to return (default: 150000)
 *   filter (NUMERIC) - 128-bit bitmask for operation type filtering
 *   include_reversible (BOOLEAN) - Include reversible blocks (default: FALSE)
 *   group_by_block (BOOLEAN) - Group results by block (default: FALSE)
 *
 * DELEGATES TO: hafah_backend.enum_virtual_ops_json()
 */
CREATE FUNCTION hafah_endpoints.call_enum_virtual_ops(_params JSON, _json_type TEXT, _is_legacy_style BOOLEAN = FALSE, _id JSON = NULL)
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
  
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
  END;

  BEGIN
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
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int_exception(_id);
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
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
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
    RETURN hafah_backend.enum_virtual_ops_json(__filter, __block_range_begin, __block_range_end, __operation_begin, __limit, __include_reversible, __group_by_block);
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      IF __exception_message ~ 'op_id cannot be None' THEN
        RETURN hafah_backend.raise_operation_id_exception(_id);
      ELSE
        RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
      END IF;
  END;
END
$$
;

/*
 * call_get_transaction: JSON-RPC wrapper for get_transaction method.
 *
 * PURPOSE: Retrieve a transaction by its hash.
 *
 * PARAMETERS (from JSON-RPC params):
 *   id (TEXT) - 40-character hex transaction hash [REQUIRED]
 *   include_reversible (BOOLEAN) - Include reversible blocks (default: FALSE)
 *
 * VALIDATION:
 *   - Hash must be exactly 40 hex characters
 *   - Only valid hex characters (0-9, a-f, A-F) allowed
 *
 * DELEGATES TO: hafah_backend.get_transaction_json()
 */
CREATE FUNCTION hafah_endpoints.call_get_transaction(_params JSON, _json_type TEXT, _is_legacy_style BOOLEAN = FALSE, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __id TEXT; -- required
  __include_reversible BOOLEAN = NULL; -- default FALSE

  __exception_message TEXT;
BEGIN
  __id = hafah_backend.parse_argument(_params, _json_type, 'id', 0);
  IF __id IS NULL THEN
    RETURN hafah_backend.raise_missing_arg('id', _id);
  END IF;

  IF NOT (translate(__id, '0123456789abcdefABCDEF', '') = '') THEN
    RETURN hafah_backend.raise_invalid_char_in_hex(__id, _id);
  ELSEIF length(__id) != 40 THEN
    RETURN hafah_backend.raise_transaction_hash_invalid_length(__id, _id);
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
    RETURN hafah_backend.get_transaction_json(decode(__id, 'hex'), __include_reversible, _is_legacy_style);
  EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END
$$
;

/*
 * call_get_account_history: JSON-RPC wrapper for get_account_history method.
 *
 * PURPOSE: Get operation history for a specific account.
 *
 * PARAMETERS (from JSON-RPC params):
 *   account (VARCHAR) - Account name to query [REQUIRED, max 16 chars]
 *   start (BIGINT) - Starting sequence number (default: -1 = most recent)
 *                    Negative values count from end: -1 = last, -100 = 100th from last
 *   limit (BIGINT) - Max operations to return (default: 1000)
 *   operation_filter_low (NUMERIC) - Bits 0-63 of 128-bit operation type bitmask
 *   operation_filter_high (NUMERIC) - Bits 64-127 of 128-bit operation type bitmask
 *   include_reversible (BOOLEAN) - Include reversible blocks (default: FALSE)
 *
 * FILTER BITMASK: 128-bit mask split into two 64-bit integers for operation type filtering.
 *                 Use hafah_backend.translate_get_account_history_filter() to decode.
 *
 * DELEGATES TO: hafah_backend.ah_get_account_history_json()
 */
CREATE FUNCTION hafah_endpoints.call_get_account_history(_params JSON, _json_type TEXT, _is_legacy_style BOOLEAN = FALSE, _id JSON = NULL)
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
    IF LENGTH(__account) > 16 THEN
      RETURN hafah_backend.raise_account_name_too_long(__account, _id);
    END IF;
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
      __operation_filter_low = NULL;
    END IF;

    __operation_filter_high = hafah_backend.parse_argument(_params, _json_type, 'operation_filter_high', 4);
    IF __operation_filter_high IS NOT NULL THEN
      __operation_filter_high = __operation_filter_high::NUMERIC;
    ELSE
      __operation_filter_high = NULL;
    END IF;

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int_exception(_id);
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
    RETURN hafah_backend.ah_get_account_history_json(
      __operation_filter_low, __operation_filter_high,
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

/*
 * call_get_block: JSON-RPC wrapper for block_api.get_block method.
 *
 * PURPOSE: Retrieve a full signed block with transactions.
 *
 * PARAMETERS (from JSON-RPC params):
 *   block_num (BIGINT) - Block number to retrieve [REQUIRED]
 *                        Handles two's complement overflow for negative values.
 *
 * DELEGATES TO: hive.get_block_json() (HAF core function)
 */
CREATE OR REPLACE FUNCTION hafah_endpoints.call_get_block(_params JSON, _json_type TEXT, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  BEGIN
    __block_num = hafah_backend.parse_argument(_params, _json_type, 'block_num', 0);
    IF __block_num IS NOT NULL THEN
      __block_num = __block_num::BIGINT;
      IF __block_num < 0 THEN
        __block_num := __block_num + (POW(2, 32) :: BIGINT);
      END IF;
    ELSE
      RETURN hafah_backend.raise_missing_arg('block_num', _id);
    END IF;

    RETURN hive.get_block_json(__block_num::INT);

  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END
$$
;

/*
 * call_get_block_header: JSON-RPC wrapper for block_api.get_block_header method.
 *
 * PURPOSE: Retrieve block header (metadata) without transactions.
 *
 * PARAMETERS (from JSON-RPC params):
 *   block_num (BIGINT) - Block number to retrieve [REQUIRED]
 *
 * DELEGATES TO: hive.get_block_header_json() (HAF core function)
 */
CREATE OR REPLACE FUNCTION hafah_endpoints.call_get_block_header(_params JSON, _json_type TEXT, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  BEGIN
    __block_num = hafah_backend.parse_argument(_params, _json_type, 'block_num', 0);
    IF __block_num IS NOT NULL THEN
      __block_num = __block_num::BIGINT;
      IF __block_num < 0 THEN
        __block_num := __block_num + (POW(2, 32) :: BIGINT);
      END IF;
    ELSE
      RETURN hafah_backend.raise_missing_arg('block_num', _id);
    END IF;

    RETURN hive.get_block_header_json(__block_num::INT);
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END
$$
;

/*
 * call_get_block_range: JSON-RPC wrapper for block_api.get_block_range method.
 *
 * PURPOSE: Retrieve multiple consecutive blocks.
 *
 * PARAMETERS (from JSON-RPC params):
 *   starting_block_num (BIGINT) - First block in range [REQUIRED]
 *   count (BIGINT) - Number of blocks to return [REQUIRED]
 *
 * DELEGATES TO: hive.get_block_range_json() (HAF core function)
 */
CREATE OR REPLACE FUNCTION hafah_endpoints.call_get_block_range(_params JSON, _json_type TEXT, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __starting_block_num BIGINT = NULL;
    __block_count BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  BEGIN
    __starting_block_num = hafah_backend.parse_argument(_params, _json_type, 'starting_block_num', 0);
    IF __starting_block_num IS NOT NULL THEN
      __starting_block_num = __starting_block_num::BIGINT;
      IF __starting_block_num < 0 THEN
        __starting_block_num := __starting_block_num + (POW(2, 32) :: BIGINT);
      END IF;
    ELSE
      RETURN hafah_backend.raise_missing_arg('starting_block_num', _id);
    END IF;

    __block_count = hafah_backend.parse_argument(_params, _json_type, 'count', 1);
    IF __block_count IS NOT NULL THEN
      __block_count = __block_count::BIGINT;
      IF __block_count < 0 THEN
        __block_count := __block_count + (POW(2, 32) :: BIGINT);
      END IF;
    ELSE
      RETURN hafah_backend.raise_missing_arg('count', _id);
    END IF;

    RETURN hive.get_block_range_json(__starting_block_num::INT, __block_count::INT);
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN hafah_backend.raise_uint_exception(_id);
    WHEN numeric_value_out_of_range THEN
      RETURN hafah_backend.raise_int32_exception(_id);
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.wrap_sql_exception(__exception_message, _id);
  END;
END
$$
;

/*
 * get_version: Returns API version info for JSON-RPC hive_api.get_version.
 *
 * RETURNS: JSON object with app_name and commit hash.
 */
CREATE FUNCTION hafah_endpoints.get_version()
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN json_build_object('app_name', 'PostgRESTHAfAH', 'commit', (SELECT git_hash FROM hafah_backend.version LIMIT 1));
END;
$$
;

/*
 * Direct PostgREST RPC wrappers (new-style API):
 * These thin wrappers allow direct calls via POST /rpc/{function_name}
 * without the JSON-RPC envelope. They delegate to the call_* functions.
 */
CREATE FUNCTION hafah_endpoints.get_ops_in_block(JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.call_get_ops_in_block($1, json_typeof($1));
END
$$
;

CREATE FUNCTION hafah_endpoints.enum_virtual_ops(JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.call_enum_virtual_ops($1, json_typeof($1));
END
$$
;

CREATE FUNCTION hafah_endpoints.get_transaction(JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.call_get_transaction($1, json_typeof($1));
END
$$
;

CREATE FUNCTION hafah_endpoints.get_account_history(JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.call_get_account_history($1, json_typeof($1));
END
$$
;

RESET ROLE;
