SET ROLE hafah_owner;

/** Converts given BIGINT value to number or string according to official JSON specification defining them as Double-precision floating-point format standard (range [-(2**53)+1, (2**53)-1])
*/
CREATE OR REPLACE FUNCTION hafah_backend.json_stringify_bigint(in n BIGINT)
RETURNS JSONB
IMMUTABLE
LANGUAGE plpgsql
AS
$$
DECLARE
  __json_min_safe_integer BIGINT := -9007199254740991;
  __json_max_safe_integer BIGINT := 9007199254740991;
begin
RETURN (SELECT CASE
          WHEN n BETWEEN __json_min_safe_integer AND __json_max_safe_integer
            THEN to_jsonb(n)
          ELSE
            to_jsonb(n::TEXT)
         END
       )
  ;
END;
$$;

CREATE OR REPLACE FUNCTION hafah_backend.numeric_to_bigint(NUMERIC)
  RETURNS BIGINT
  IMMUTABLE
  AS $$
DECLARE
  MAX_BIGINT BIGINT := x'7fffffffffffffff'::BIGINT;
  MIN_BIGINT BIGINT := (1 :: BIGINT << 63);
BEGIN
  IF $1 IS NULL THEN
    RETURN NULL :: BIGINT;
  END IF;

  IF $1 < 0 THEN
    RETURN NULL;
  ELSEIF $1 > MAX_BIGINT THEN
    RETURN (MIN_BIGINT | ((($1 + MIN_BIGINT) :: BIGINT ))) :: BIGINT;
  ELSE
    RETURN $1 :: BIGINT;
  END IF;
END;
$$ LANGUAGE plpgsql;

RESET ROLE;
