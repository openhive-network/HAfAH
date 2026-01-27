SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.find_positive_bit(in _N BIGINT, in _START SMALLINT) RETURNS SMALLINT AS $function$
BEGIN
  FOR i IN GREATEST(_START, 0)..63 LOOP
    IF _N & (1 ::BIGINT << i) != 0 THEN
      RETURN i;
    END IF;
  END LOOP;
  RETURN NULL;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.get_bit_positions_64(in _in BIGINT, in _offset SMALLINT) RETURNS SMALLINT[] AS
$function$
DECLARE
  temp_value BIGINT := 0;
  input_data BIGINT := _in;
  last_found_pos SMALLINT := 0;
  result SMALLINT[] := ARRAY[] ::SMALLINT[];
  MIN_BIGINT_VALUE BIGINT := (1 :: BIGINT << 63);
BEGIN

  IF _in IS NULL THEN
    RETURN NULL :: BIGINT;
  END IF;

  WHILE input_data != 0 LOOP
    IF input_data = MIN_BIGINT_VALUE THEN
      -- substraction from MIN_BIGINT_VALUE will raise exception, that's why
      -- custom behaivior is performed
      input_data := 0;
      last_found_pos := 63;
    ELSE
      temp_value := input_data - 1;
      input_data := input_data & temp_value;
      last_found_pos := hafah_backend.find_positive_bit(input_data # (temp_value + 1), last_found_pos);
    END IF;
    result := array_append(result, last_found_pos + _offset );
  END LOOP;

  RETURN result;

END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_backend.get_bit_positions_128(_low BIGINT, _high BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN (
    SELECT ( (SELECT hafah_backend.get_bit_positions_64(_low, 0 :: SMALLINT)) || (SELECT hafah_backend.get_bit_positions_64(_high, 64 :: SMALLINT)) )
  );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_backend.translate_enum_virtual_ops_filter(_in BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN ( SELECT hafah_backend.get_bit_positions_64(_in, (SELECT id FROM hafd.operation_types WHERE is_virtual=TRUE ORDER BY id ASC LIMIT 1) ) );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_backend.translate_get_account_history_filter(_low BIGINT, _high BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN ( SELECT hafah_backend.get_bit_positions_128(_low, _high ) );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

RESET ROLE;
