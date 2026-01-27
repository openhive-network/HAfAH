SET ROLE hafah_owner;

/*
 * exception_parsing.sql: JSON-RPC exception generation utilities.
 *
 * Used by: JSON-RPC method handlers in endpoints/dispatcher.sql
 *
 * This file contains functions for generating JSON-RPC 2.0 compliant error responses.
 * These are argument-related exceptions used during JSON-RPC request processing.
 *
 * JSON-RPC 2.0 ERROR CODES:
 *   Standard codes (reserved range -32000 to -32099):
 *     -32700  Parse error      Invalid JSON
 *     -32600  Invalid Request  Not a valid JSON-RPC request
 *     -32601  Method not found Method does not exist
 *     -32602  Invalid params   Invalid method parameters
 *     -32603  Internal error   Internal JSON-RPC error
 *
 *   Server errors (implementation-defined, -32000 to -32099):
 *     -32000  Parse Error      Type coercion failures (uint64, int64, etc.)
 *     -32003  Assert Exception Server-side assertion failures
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
  /*
   * JSON-RPC 2.0 ERROR RESPONSE FORMAT:
   *   {
   *     "jsonrpc": "2.0",
   *     "error": {
   *       "code": <integer>,      -- Required: error code
   *       "message": <string>,    -- Required: short description
   *       "data": <any>           -- Optional: additional info
   *     },
   *     "id": <request-id>        -- Must match request id (null if parse error)
   *   }
   *
   * WHY REPLACE ' :' with ':': PostgreSQL json_build_object adds space before colon.
   *     This ensures consistent formatting matching Hive node responses.
   */
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'jsonrpc', '2.0',
    'error',
    CASE
      WHEN _no_data IS TRUE THEN
        -- WHY: Some errors (parse errors) don't include data field per Hive convention
        json_build_object(
          'code', _code,
          'message', _message
        )
      ELSE
        -- NOTE: data field provides additional context (e.g., missing parameter name)
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
 * Each function matches specific error messages from original HAfAH Python.
 */

/*
 * TYPE COERCION EXCEPTIONS (-32000):
 *   These errors occur when JSON values cannot be parsed as the expected type.
 *   Message format matches Hive node for client compatibility.
 */

-- WHY: Block numbers and similar uint32 params have max 4294967295
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

/*
 * PARAMETER VALIDATION EXCEPTIONS (-32602):
 *   These errors indicate missing or invalid parameter values.
 */

-- WHY: Required parameters must be present in JSON-RPC request
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

-- WHY: Operation ID is required for get_operation endpoint
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

/*
 * INTEGER PARSING EXCEPTIONS (-32000):
 *   These match Hive's C++ type parsing error messages.
 *   Each integer type has its own error for precise diagnostics.
 */

-- WHY: 64-bit unsigned integer parsing failed (e.g., negative value, overflow)
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

-- WHY: 64-bit signed integer parsing failed
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

-- WHY: 32-bit signed integer parsing failed (block_num, trx_in_block)
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

/*
 * BOOLEAN CASE EXCEPTION:
 *   JSON spec requires lowercase true/false. "True", "False", "TRUE" are invalid.
 *   See parse_argument() in argument_parsing.sql for validation logic.
 */
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
 * ACCOUNT HISTORY LIMIT EXCEPTION:
 *   Triggered when limit parameter has unsigned overflow (negative becomes huge positive).
 *   See parse_acc_hist_limit() - when -1 becomes 4294967295 after conversion.
 *
 * WHY: Replicates exact HAfAH Python error message for client compatibility.
 *      The typo "maxmimum" is intentional - matches original Hive error.
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

/*
 * TRANSACTION HASH EXCEPTIONS:
 *   Transaction hashes are 20-byte (160-bit) hex strings.
 *   These exceptions handle validation errors.
 */

-- WHY: Hex strings must only contain 0-9, a-f, A-F
--      ltrim removes valid chars, leaving first invalid char for the error message
CREATE FUNCTION hafah_backend.raise_invalid_char_in_hex(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN hafah_backend.raise_exception(
    -32000,
    format(
      'unspecified:Invalid hex character ''%s''',
      left(ltrim(_hex, '0123456789abcdefABCDEF'), 1)  -- Extract first non-hex character
    ),
    NULL, _id, TRUE
  );
END
$$;

-- WHY: Transaction hashes must be exactly 40 hex chars (20 bytes = 160 bits)
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

-- WHY: Transaction hash is valid format but doesn't exist in blockchain
--      rpad ensures consistent 40-char display even for short hashes
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

/*
 * ACCOUNT NAME EXCEPTION:
 *   Hive account names are limited to 16 characters.
 *   This matches the C++ fixed_string<16> size limit.
 */
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
