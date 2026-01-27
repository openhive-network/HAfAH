SET ROLE hafah_owner;

/*
 * exception_parsing.sql: JSON-RPC exception generation utilities.
 *
 * Used by: JSON-RPC method handlers in endpoints/dispatcher.sql
 *
 * This file contains functions for generating JSON-RPC 2.0 compliant error responses.
 * These are argument-related exceptions used during JSON-RPC request processing.
 *
 * Note: Argument parsing functions are in argument_parsing.sql
 */

/* =============================================================================
 * SECTION 1: Core Exception Functions
 * =============================================================================
 * Base functions for building JSON-RPC error responses.
 */

/*
 * ===================================================================================
 * raise_exception
 * ===================================================================================
 * PURPOSE: Build a JSON-RPC 2.0 error response object.
 *
 * PARAMETERS:
 *   - _code: Error code (negative for standard errors)
 *   - _message: Human-readable error message
 *   - _data: Additional error data (optional)
 *   - _id: Request ID to include in response
 *   - _no_data: If TRUE, omit the data field
 *
 * RETURNS: JSON error response object
 */
CREATE FUNCTION hafah_backend.raise_exception(
    _code    INT,
    _message TEXT,
    _data    TEXT    = NULL,
    _id      JSON    = NULL,
    _no_data BOOLEAN = FALSE
)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'jsonrpc', '2.0',
    'error',
    CASE
      WHEN _no_data IS TRUE THEN
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
$$;

/*
 * ===================================================================================
 * wrap_sql_exception
 * ===================================================================================
 * PURPOSE: Wrap a SQL exception message in JSON-RPC error format.
 *
 * Uses error code -32003 (server error).
 */
CREATE FUNCTION hafah_backend.wrap_sql_exception(
    _exception_message TEXT,
    _id                JSON = NULL
)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(-32003, _exception_message, NULL, _id, TRUE);
END
$$;

/* =============================================================================
 * SECTION 2: Specific Exception Functions
 * =============================================================================
 * Pre-defined exception generators for common error cases.
 */

CREATE FUNCTION hafah_backend.raise_exceed_max_uint32_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    'Parse Error:Exceeded maximum value for uint32_t',
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_missing_arg(_arg_name TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32602,
    'Invalid parameters',
    format('missing a required argument: ''%s''', _arg_name),
    _id
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_operation_id_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32602,
    'Invalid parameters',
    'op_id cannot be None',
    _id
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_uint_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    'Parse Error:Couldn''t parse uint64_t',
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_int_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    'Parse Error:Couldn''t parse int64_t',
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_int32_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    'Parse Error:Couldn''t parse int32_t',
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_bool_case_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    'Bad Cast:Cannot convert string to bool (only "true" or "false" can be converted)',
    NULL, _id, TRUE
  );
END
$$;

/*
 * Replicates HAfAH Python behavior for below-zero account history limit
 */
CREATE FUNCTION hafah_backend.raise_below_zero_acc_hist(_id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.wrap_sql_exception(
    'Assert Exception:args.limit <= 1000: limit of 4294967295 is greater than maxmimum allowed',
    _id
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_invalid_char_in_hex(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    format(
      'unspecified:Invalid hex character ''%s''',
      left(ltrim(_hex, '0123456789abcdefABCDEF'), 1)
    ),
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_transaction_hash_invalid_length(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32003,
    format(
      'Assert Exception:false: Transaction hash ''%s'' has invalid size. Transaction hash should have size of 160 bits',
      _hex
    ),
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_unknown_transaction(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32003,
    format('Assert Exception:false: Unknown Transaction %s', rpad(_hex, 40, '0')),
    NULL, _id, TRUE
  );
END
$$;

CREATE FUNCTION hafah_backend.raise_account_name_too_long(_account_name TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32003,
    format(
      'Assert Exception:in_len <= sizeof(data): Input too large: `%s` (%s) for fixed size string: (16)',
      _account_name,
      LENGTH(_account_name)
    ),
    NULL, _id, TRUE
  );
END
$$;

RESET ROLE;
