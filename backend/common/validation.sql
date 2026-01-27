SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.validate_limit( in GIVEN_LIMIT BIGINT, in EXPECTED_LIMIT INT, GIVEN_LIMIT_NAME TEXT DEFAULT 'limit' ) RETURNS VOID AS $function$
BEGIN
  IF GIVEN_LIMIT > EXPECTED_LIMIT THEN
    RAISE EXCEPTION 'Assert Exception:args.% <= %: % of % is greater than maxmimum allowed', GIVEN_LIMIT_NAME, EXPECTED_LIMIT, GIVEN_LIMIT_NAME, GIVEN_LIMIT;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.validate_negative_limit( in _limit BIGINT, GIVEN_LIMIT_NAME TEXT DEFAULT 'limit' ) RETURNS VOID AS $function$
BEGIN
  IF _limit <= 0 THEN
    RAISE EXCEPTION 'Assert Exception:% > 0: % of % is lesser or equal 0', GIVEN_LIMIT_NAME, GIVEN_LIMIT_NAME, _limit;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.validate_page( in GIVEN_PAGE BIGINT, in MAX_PAGE INT ) RETURNS VOID AS $function$
BEGIN
  IF GIVEN_PAGE > MAX_PAGE AND GIVEN_PAGE != 1 THEN
    RAISE EXCEPTION 'Assert Exception:args.page <= %: page of % is greater than maxmimum page', MAX_PAGE, GIVEN_PAGE;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.validate_negative_page( in given_page BIGINT ) RETURNS VOID AS $function$
BEGIN
  IF given_page <= 0 THEN
    RAISE EXCEPTION 'Assert Exception:page <= 0: page of % is lesser or equal 0', given_page;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.validate_start_limit( in _start BIGINT, in _limit BIGINT ) RETURNS VOID AS $function$
BEGIN
  IF _start < (_limit - 1) OR _limit = 0 THEN
    RAISE EXCEPTION 'Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)';
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_backend.validate_block_range( in BLOCK_START INT, in BLOCK_STOP INT, in EXPECTED_DISTANCE INT ) RETURNS VOID AS $function$
BEGIN
  IF BLOCK_STOP - BLOCK_START > EXPECTED_DISTANCE THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd - blockRangeBegin <= block_range_limit: Block range distance must be less than or equal to 2000';
  END IF;

  IF BLOCK_STOP <= BLOCK_START THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd > blockRangeBegin: Block range must be upward';
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

RESET ROLE;
