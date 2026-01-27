SET ROLE hafah_owner;

/*
 * bit_operations.sql: Bit manipulation for operation filters.
 *
 * Functions:
 *   - hafah_backend.find_positive_bit() - Find first positive bit from given position
 *   - hafah_backend.get_bit_positions_64() - Get array of set bit positions in 64-bit value
 *   - hafah_backend.get_bit_positions_128() - Get array of set bit positions in 128-bit value
 *   - hafah_backend.translate_enum_virtual_ops_filter() - Translate virtual ops filter bitmask
 *   - hafah_backend.translate_get_account_history_filter() - Translate account history filter bitmask
 */

/*
 * ===================================================================================
 * find_positive_bit
 * ===================================================================================
 * PURPOSE: Finds the first positive (set) bit in a BIGINT starting from a given position.
 *
 * PARAMETERS:
 *   _n     - The BIGINT value to search
 *   _start - Starting bit position (0-based)
 *
 * RETURNS: SMALLINT - position of first set bit, or NULL if none found
 */
CREATE OR REPLACE FUNCTION hafah_backend.find_positive_bit(
    _n        BIGINT,
    _start    SMALLINT
)
RETURNS SMALLINT
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  FOR i IN GREATEST(_start, 0)..63 LOOP
    IF _n & (1::BIGINT << i) != 0 THEN
      RETURN i;
    END IF;
  END LOOP;
  RETURN NULL;
END
$$;

/*
 * ===================================================================================
 * get_bit_positions_64
 * ===================================================================================
 * PURPOSE: Returns array of all set bit positions in a 64-bit integer, with optional offset.
 *
 * PARAMETERS:
 *   _in     - The BIGINT value to analyze
 *   _offset - Offset to add to each bit position
 *
 * RETURNS: SMALLINT[] - array of bit positions that are set
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_bit_positions_64(
    _in       BIGINT,
    _offset   SMALLINT
)
RETURNS SMALLINT[]
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
DECLARE
  __temp_value BIGINT := 0;
  __input_data BIGINT := _in;
  __last_found_pos SMALLINT := 0;
  __result SMALLINT[] := ARRAY[]::SMALLINT[];
  __min_bigint_value BIGINT := (1::BIGINT << 63);
BEGIN
  IF _in IS NULL THEN
    RETURN NULL::BIGINT;
  END IF;

  WHILE __input_data != 0 LOOP
    IF __input_data = __min_bigint_value THEN
      -- subtraction from MIN_BIGINT_VALUE will raise exception, that's why
      -- custom behavior is performed
      __input_data := 0;
      __last_found_pos := 63;
    ELSE
      __temp_value := __input_data - 1;
      __input_data := __input_data & __temp_value;
      __last_found_pos := hafah_backend.find_positive_bit(__input_data # (__temp_value + 1), __last_found_pos);
    END IF;
    __result := array_append(__result, __last_found_pos + _offset);
  END LOOP;

  RETURN __result;
END
$$;

/*
 * ===================================================================================
 * get_bit_positions_128
 * ===================================================================================
 * PURPOSE: Returns array of all set bit positions across two 64-bit integers (128 bits total).
 *
 * PARAMETERS:
 *   _low  - Lower 64 bits
 *   _high - Upper 64 bits
 *
 * RETURNS: SMALLINT[] - array of bit positions that are set (0-127)
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_bit_positions_128(
    _low     BIGINT,
    _high    BIGINT
)
RETURNS SMALLINT[]
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (
    SELECT (
      (SELECT hafah_backend.get_bit_positions_64(_low, 0::SMALLINT)) ||
      (SELECT hafah_backend.get_bit_positions_64(_high, 64::SMALLINT))
    )
  );
END
$$;

/*
 * ===================================================================================
 * translate_enum_virtual_ops_filter
 * ===================================================================================
 * PURPOSE: Translates a bitmask filter for virtual operations into an array of operation type IDs.
 *
 * PARAMETERS:
 *   _in - Bitmask where each bit represents a virtual operation type
 *
 * RETURNS: SMALLINT[] - array of operation type IDs
 */
CREATE OR REPLACE FUNCTION hafah_backend.translate_enum_virtual_ops_filter(
    _in    BIGINT
)
RETURNS SMALLINT[]
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (
    SELECT hafah_backend.get_bit_positions_64(
      _in,
      (SELECT id FROM hafd.operation_types WHERE is_virtual = TRUE ORDER BY id ASC LIMIT 1)
    )
  );
END
$$;

/*
 * ===================================================================================
 * translate_get_account_history_filter
 * ===================================================================================
 * PURPOSE: Translates a 128-bit bitmask filter for account history into an array of operation type IDs.
 *
 * PARAMETERS:
 *   _low  - Lower 64 bits of filter
 *   _high - Upper 64 bits of filter
 *
 * RETURNS: SMALLINT[] - array of operation type IDs
 */
CREATE OR REPLACE FUNCTION hafah_backend.translate_get_account_history_filter(
    _low     BIGINT,
    _high    BIGINT
)
RETURNS SMALLINT[]
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (SELECT hafah_backend.get_bit_positions_128(_low, _high));
END
$$;

RESET ROLE;
