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
  __json_min_safe_integer BIGINT := -9007199254740991;
  __json_max_safe_integer BIGINT := 9007199254740991;
BEGIN
  RETURN (
    SELECT CASE
      WHEN _n BETWEEN __json_min_safe_integer AND __json_max_safe_integer THEN
        to_jsonb(_n)
      ELSE
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
  __max_bigint BIGINT := x'7fffffffffffffff'::BIGINT;
  __min_bigint BIGINT := (1::BIGINT << 63);
BEGIN
  IF $1 IS NULL THEN
    RETURN NULL::BIGINT;
  END IF;

  IF $1 < 0 THEN
    RETURN NULL;
  ELSIF $1 > __max_bigint THEN
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
 * Converts negative start values to max BIGINT (meaning "from the end").
 *
 * PARAMETERS:
 *   - _start: Start position (can be negative)
 *
 * RETURNS: Normalized start value
 */
CREATE FUNCTION hafah_backend.parse_acc_hist_start(_start BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN CASE
    WHEN _start < 0 THEN 9223372036854775807
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
 * Handles unsigned integer wraparound from client (negative values become large).
 *
 * PARAMETERS:
 *   - _limit: Limit value (can be negative due to unsigned conversion)
 *
 * RETURNS: Normalized limit value
 */
CREATE FUNCTION hafah_backend.parse_acc_hist_limit(_limit BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RETURN CASE
    WHEN _limit < 0 THEN (2^32) + _limit
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
 * Supports both object-style {"param": value} and array-style [value1, value2].
 *
 * PARAMETERS:
 *   - _params: JSON params from request
 *   - _json_type: "object" or "array"
 *   - _arg_name: Parameter name (for object style)
 *   - _arg_number: Parameter position (for array style)
 *   - _is_bool: If TRUE, validates boolean format
 *
 * RETURNS: Parameter value as TEXT
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
  SELECT CASE
    WHEN _json_type = 'object' THEN _params ->> _arg_name
    ELSE _params ->> _arg_number
  END INTO __param;

  -- Validate boolean format (replicates HAfAH Python behavior)
  IF _is_bool IS TRUE AND __param ~ '([A-Z].+)' THEN
    RAISE invalid_text_representation;
  ELSE
    RETURN __param;
  END IF;
END
$$;

RESET ROLE;
