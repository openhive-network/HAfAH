SET ROLE hafah_owner;

/*
 * argument_parsing.sql: JSON-RPC argument parsing and JSON utilities.
 *
 * Used by: hafah_endpoints.home() in dispatcher.sql
 *
 * This file contains:
 *   1. JSON utility functions for safe type conversions
 *   2. Argument parsing functions for JSON-RPC parameters
 *
 * Note: Exception generation functions are in exception_parsing.sql
 */

/* =============================================================================
 * SECTION 1: JSON Utility Functions
 * =============================================================================
 * Functions for safe JSON type conversions.
 */

/*
 * ===================================================================================
 * json_stringify_bigint
 * ===================================================================================
 * PURPOSE: Converts given BIGINT value to number or string according to official JSON
 *          specification defining them as Double-precision floating-point format
 *          standard (range [-(2**53)+1, (2**53)-1]).
 *
 * PARAMETERS:
 *   _n - The BIGINT value to convert
 *
 * RETURNS: JSONB - number if within safe range, string otherwise
 */
CREATE OR REPLACE FUNCTION hafah_backend.json_stringify_bigint(
    _n    BIGINT
)
RETURNS JSONB
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
DECLARE
  /*
   * IEEE 754 SAFE INTEGER RANGE:
   *   JSON numbers are specified as double-precision floating-point (IEEE 754).
   *   This format uses 52 bits for the mantissa, giving exact integer representation
   *   only for values in the range [-(2^53)+1, (2^53)-1] = [-9007199254740991, 9007199254740991].
   *
   * WHY: Values outside this range lose precision when parsed by JavaScript/JSON clients.
   *      Example: 9007199254740993 becomes 9007199254740992 in JavaScript.
   *
   * NOTE: PostgreSQL BIGINT range is [-2^63, 2^63-1], much larger than JSON safe range.
   */
  __json_min_safe_integer BIGINT := -9007199254740991;  -- -(2^53) + 1
  __json_max_safe_integer BIGINT := 9007199254740991;   -- (2^53) - 1
BEGIN
  RETURN (
    SELECT CASE
      WHEN _n BETWEEN __json_min_safe_integer AND __json_max_safe_integer THEN
        -- WHY: Safe to return as number - no precision loss
        to_jsonb(_n)
      ELSE
        -- WHY: Return as string to preserve full precision for large values
        to_jsonb(_n::TEXT)
    END
  );
END
$$;

/*
 * ===================================================================================
 * numeric_to_bigint
 * ===================================================================================
 * PURPOSE: Converts NUMERIC to BIGINT with proper handling of values that exceed
 *          BIGINT range using two's complement overflow.
 *
 * PARAMETERS:
 *   $1 - The NUMERIC value to convert
 *
 * RETURNS: BIGINT - converted value, NULL if input is NULL or negative
 */
CREATE OR REPLACE FUNCTION hafah_backend.numeric_to_bigint(
    NUMERIC
)
RETURNS BIGINT
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
DECLARE
  /*
   * TWO'S COMPLEMENT OVERFLOW HANDLING:
   *   JSON-RPC clients may send unsigned 64-bit values that exceed PostgreSQL's
   *   signed BIGINT range (max 9223372036854775807 = 0x7FFFFFFFFFFFFFFF).
   *
   * WHY: Hive uses unsigned 128-bit bitmasks for operation filters. When split
   *      into two 64-bit parts, the high bits can exceed signed BIGINT max.
   *
   * EXAMPLE:
   *   Client sends: 18446744073709551615 (max uint64, 0xFFFFFFFFFFFFFFFF)
   *   Direct cast would fail (exceeds BIGINT max)
   *   This function wraps it using two's complement to: -1
   */
  __max_bigint BIGINT := x'7fffffffffffffff'::BIGINT;  -- 9223372036854775807 (max signed BIGINT)
  __min_bigint BIGINT := (1::BIGINT << 63);             -- -9223372036854775808 (min signed BIGINT, used as bitmask)
BEGIN
  IF $1 IS NULL THEN
    RETURN NULL::BIGINT;
  END IF;

  IF $1 < 0 THEN
    -- WHY: Negative NUMERIC values are invalid for this conversion
    RETURN NULL;
  ELSIF $1 > __max_bigint THEN
    /*
     * OVERFLOW CONVERSION:
     *   For values > max signed BIGINT, apply two's complement wrapping.
     *   This preserves the bit pattern when interpreted as unsigned.
     *
     *   Formula: result = (min_bigint) | ((value + min_bigint) as BIGINT)
     *   Effect: Wraps 9223372036854775808+ to negative range (-9223372036854775808+)
     */
    RETURN (__min_bigint | ((($1 + __min_bigint)::BIGINT)))::BIGINT;
  ELSE
    RETURN $1::BIGINT;
  END IF;
END
$$;

/* =============================================================================
 * SECTION 2: Argument Parsing Functions
 * =============================================================================
 * Functions for parsing and normalizing JSON-RPC method arguments.
 */

/*
 * ===================================================================================
 * parse_acc_hist_start
 * ===================================================================================
 * PURPOSE: Normalize the 'start' parameter for account history queries.
 *
 * NEGATIVE START VALUES CONVENTION:
 *   In account history API, start=-1 (or any negative) means "from the most recent".
 *   This matches Hive node behavior where account_op_seq_no starts at 0 and increases.
 *
 *   Example: Account with operations [0,1,2,3,4,5]
 *     start=-1, limit=3  → Returns [5,4,3] (most recent 3)
 *     start=3,  limit=3  → Returns [3,2,1] (from seq 3 backwards)
 *
 * PARAMETERS:
 *   - _start: Start position (negative means "from end")
 *
 * RETURNS: Normalized start value (max BIGINT for negative input)
 */
CREATE FUNCTION hafah_backend.parse_acc_hist_start(_start BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN CASE
    -- WHY: Negative start means "from the end" - use max value to include all recent ops
    WHEN _start < 0 THEN 9223372036854775807  -- Max BIGINT: ensures we start from most recent
    ELSE _start
  END;
END
$$;

/*
 * ===================================================================================
 * parse_acc_hist_limit
 * ===================================================================================
 * PURPOSE: Normalize the 'limit' parameter for account history queries.
 *
 * UNSIGNED INTEGER WRAPAROUND:
 *   Hive clients may pass limit as uint32_t. When transmitted via JSON-RPC and
 *   parsed by PostgreSQL as signed BIGINT, values > 2^31-1 appear negative.
 *
 *   Example: Client sends uint32 limit=4294967295 (0xFFFFFFFF, max uint32)
 *            PostgreSQL sees: -1 (signed interpretation)
 *            This function converts back: (2^32) + (-1) = 4294967295
 *
 * WHY: Maintains compatibility with original HAfAH Python behavior which
 *      handled this case by raising "limit of 4294967295 is greater than maximum".
 *
 * PARAMETERS:
 *   - _limit: Limit value (can be negative due to unsigned-to-signed conversion)
 *
 * RETURNS: Normalized unsigned limit value
 */
CREATE FUNCTION hafah_backend.parse_acc_hist_limit(_limit BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN CASE
    -- WHY: Reconstruct original unsigned value from two's complement negative
    WHEN _limit < 0 THEN (2^32) + _limit  -- Convert signed back to unsigned range
    ELSE _limit
  END;
END
$$;

/*
 * ===================================================================================
 * parse_argument
 * ===================================================================================
 * PURPOSE: Extract an argument from JSON-RPC params by name or position.
 *
 * TWO-STYLE JSON-RPC PARSING:
 *   JSON-RPC 2.0 allows params to be either an object or an array:
 *
 *   Object style (named parameters):
 *     {"jsonrpc":"2.0","method":"get_account_history","params":{"account":"alice","start":-1,"limit":10}}
 *     Access via: _params ->> 'account'
 *
 *   Array style (positional parameters):
 *     {"jsonrpc":"2.0","method":"get_account_history","params":["alice",-1,10]}
 *     Access via: _params ->> 0
 *
 *   The dispatcher determines style via: json_typeof(params)
 *   Then passes _json_type = 'object' or 'array' to this function.
 *
 * PARAMETERS:
 *   - _params: JSON params from request (object or array)
 *   - _json_type: "object" for named params, "array" for positional
 *   - _arg_name: Parameter name (used when _json_type = 'object')
 *   - _arg_number: Parameter position, 0-indexed (used when _json_type = 'array')
 *   - _is_bool: If TRUE, validates that boolean uses lowercase (true/false)
 *
 * RETURNS: Parameter value as TEXT (caller converts to appropriate type)
 */
CREATE FUNCTION hafah_backend.parse_argument(
    _params     JSON,
    _json_type  TEXT,
    _arg_name   TEXT,
    _arg_number INT,
    _is_bool    BOOLEAN = FALSE
)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS $$
DECLARE
  __param TEXT;
BEGIN
  /*
   * PARAMETER EXTRACTION:
   *   ->> operator extracts as TEXT, works with both string keys and integer indices
   */
  SELECT CASE
    WHEN _json_type = 'object' THEN _params ->> _arg_name    -- Named: {"account": "alice"}
    ELSE _params ->> _arg_number                             -- Positional: ["alice", -1, 10]
  END INTO __param;

  /*
   * BOOLEAN CASE VALIDATION:
   *   JSON spec requires lowercase: true/false
   *   HAfAH Python rejected "True", "False", "TRUE" etc.
   *   Regex '([A-Z].+)' catches any value starting with uppercase.
   *
   * WHY: Maintains compatibility with original HAfAH behavior.
   */
  IF _is_bool IS TRUE AND __param ~ '([A-Z].+)' THEN
    RAISE invalid_text_representation;  -- Caught by caller, returns raise_bool_case_exception
  ELSE
    RETURN __param;
  END IF;
END
$$;

RESET ROLE;
