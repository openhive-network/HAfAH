SET ROLE hafah_owner;

/*
 * validators.sql: Input validation functions for both REST and JSON-RPC APIs.
 *
 * Limit Validation:
 *   - hafah_backend.validate_limit() - Validate limit does not exceed maximum
 *   - hafah_backend.validate_negative_limit() - Validate limit is positive
 *   - hafah_backend.validate_start_limit() - Validate start/limit relationship
 *
 * Page Validation:
 *   - hafah_backend.validate_page() - Validate page does not exceed maximum
 *   - hafah_backend.validate_negative_page() - Validate page is positive
 *
 * Block Validation:
 *   - hafah_backend.validate_block_range() - Validate block range constraints
 *   - hafah_backend.validate_block_num() - Validate block exists
 *
 * Account Validation:
 *   - hafah_backend.validate_account() - Validate account exists
 *   - hafah_backend.validate_participation_mode() - Validate participation mode and account
 *
 * Operation Validation:
 *   - hafah_backend.validate_operation_types() - Validate operation type IDs
 *   - hafah_backend.validate_op_type_id() - Validate single operation type ID
 *   - hafah_backend.validate_operation_id() - Validate operation ID exists
 */

-- ===================================================================================
-- LIMIT VALIDATION
-- ===================================================================================

/*
 * ===================================================================================
 * validate_limit
 * ===================================================================================
 * PURPOSE: Validates that a given limit does not exceed the expected maximum.
 *
 * PARAMETERS:
 *   _given_limit      - The limit value provided
 *   _expected_limit   - Maximum allowed limit
 *   _given_limit_name - Name of the limit parameter for error messages (default: 'limit')
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_limit(
    _given_limit         BIGINT,
    _expected_limit      INT,
    _given_limit_name    TEXT DEFAULT 'limit'
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _given_limit > _expected_limit THEN
    RAISE EXCEPTION 'Assert Exception:args.% <= %: % of % is greater than maxmimum allowed', _given_limit_name, _expected_limit, _given_limit_name, _given_limit;
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_negative_limit
 * ===================================================================================
 * PURPOSE: Validates that a limit is positive (greater than 0).
 *
 * PARAMETERS:
 *   _limit            - The limit value to validate
 *   _given_limit_name - Name of the limit parameter for error messages (default: 'limit')
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_negative_limit(
    _limit               BIGINT,
    _given_limit_name    TEXT DEFAULT 'limit'
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _limit <= 0 THEN
    RAISE EXCEPTION 'Assert Exception:% > 0: % of % is lesser or equal 0', _given_limit_name, _given_limit_name, _limit;
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_start_limit
 * ===================================================================================
 * PURPOSE: Validates the relationship between start and limit parameters.
 *          Start must be >= (limit - 1) because start is a 0-based index.
 *
 * PARAMETERS:
 *   _start - The start index (0-based)
 *   _limit - The limit value
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_start_limit(
    _start    BIGINT,
    _limit    BIGINT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _start < (_limit - 1) OR _limit = 0 THEN
    RAISE EXCEPTION 'Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)';
  END IF;
END
$$;

-- ===================================================================================
-- PAGE VALIDATION
-- ===================================================================================

/*
 * ===================================================================================
 * validate_page
 * ===================================================================================
 * PURPOSE: Validates that a page number does not exceed the maximum page.
 *          Page 1 is always allowed even if max_page is 0.
 *
 * PARAMETERS:
 *   _given_page - The requested page number
 *   _max_page   - Maximum allowed page number
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_page(
    _given_page    BIGINT,
    _max_page      INT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _given_page > _max_page AND _given_page != 1 THEN
    RAISE EXCEPTION 'Assert Exception:args.page <= %: page of % is greater than maxmimum page', _max_page, _given_page;
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_negative_page
 * ===================================================================================
 * PURPOSE: Validates that a page number is positive (greater than 0).
 *
 * PARAMETERS:
 *   _given_page - The page number to validate
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_negative_page(
    _given_page    BIGINT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _given_page <= 0 THEN
    RAISE EXCEPTION 'Assert Exception:page <= 0: page of % is lesser or equal 0', _given_page;
  END IF;
END
$$;

-- ===================================================================================
-- BLOCK VALIDATION
-- ===================================================================================

/*
 * ===================================================================================
 * validate_block_range
 * ===================================================================================
 * PURPOSE: Validates block range constraints:
 *          - Range must not exceed expected distance (typically 2000)
 *          - Range must be upward (end > start)
 *
 * PARAMETERS:
 *   _block_start      - Starting block number
 *   _block_stop       - Ending block number
 *   _expected_distance - Maximum allowed range
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_block_range(
    _block_start          INT,
    _block_stop           INT,
    _expected_distance    INT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF _block_stop - _block_start > _expected_distance THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd - blockRangeBegin <= block_range_limit: Block range distance must be less than or equal to 2000';
  END IF;

  IF _block_stop <= _block_start THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd > blockRangeBegin: Block range must be upward';
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_block_num
 * ===================================================================================
 * PURPOSE: Validates that a block number exists in the database.
 *
 * PARAMETERS:
 *   _block_num - Block number to validate
 *
 * RETURNS: VOID (raises exception if block does not exist)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_block_num(
    _block_num    INT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hive.blocks_view bv WHERE bv.num = _block_num) THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;
END
$$;

-- ===================================================================================
-- ACCOUNT VALIDATION
-- ===================================================================================

/*
 * ===================================================================================
 * validate_account
 * ===================================================================================
 * PURPOSE: Validates account existence based on account ID.
 *          If required is TRUE, account must exist.
 *          If required is FALSE, only validates if account_name was provided.
 *
 * PARAMETERS:
 *   _account_id   - Account ID (NULL if account not found)
 *   _account_name - Account name that was looked up
 *   _required     - Whether the account is required to exist
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_account(
    _account_id      INT,
    _account_name    TEXT,
    _required        BOOLEAN
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  IF (_required AND _account_id IS NULL) OR (NOT _required AND _account_name IS NOT NULL AND _account_id IS NULL) THEN
    PERFORM hafah_backend.rest_raise_missing_account(_account_name);
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_participation_mode
 * ===================================================================================
 * PURPOSE: Validates that participation mode 'all' is not used with an account name.
 *
 * PARAMETERS:
 *   _mode         - The participation mode
 *   _account_name - Account name (should be NULL for 'all' mode)
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_participation_mode(
    _mode            hafah_backend.participation_mode, -- noqa: LT01, CP05
    _account_name    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  IF _mode = 'all' AND _account_name IS NOT NULL THEN
    PERFORM hafah_backend.rest_raise_invalid_participation();
  END IF;
END
$$;

-- ===================================================================================
-- OPERATION VALIDATION
-- ===================================================================================

/*
 * ===================================================================================
 * validate_operation_types
 * ===================================================================================
 * PURPOSE: Validates that all provided operation type IDs are in the allowed list.
 *
 * PARAMETERS:
 *   _operations         - Array of operation type IDs to validate
 *   _allowed_operations - Array of allowed operation type IDs
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_operation_types(
    _operations            INT[],
    _allowed_operations    INT[]
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  IF (NOT _operations <@ _allowed_operations) AND _operations IS NOT NULL THEN
    PERFORM hafah_backend.rest_raise_invalid_operation_types(_allowed_operations);
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_op_type_id
 * ===================================================================================
 * PURPOSE: Validates that an operation type ID exists in the database.
 *
 * PARAMETERS:
 *   _op_type - Operation type ID to validate
 *
 * RETURNS: VOID (raises exception if validation fails)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_op_type_id(
    _op_type    INT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF (_op_type > (SELECT MAX(id) FROM hafd.operation_types)) OR _op_type < 0 THEN
    PERFORM hafah_backend.rest_raise_missing_op_type(_op_type);
  END IF;
END
$$;

/*
 * ===================================================================================
 * validate_operation_id
 * ===================================================================================
 * PURPOSE: Validates that an operation ID exists in the database.
 *
 * PARAMETERS:
 *   _operation_id - Operation ID to validate
 *
 * RETURNS: VOID (raises exception if operation does not exist)
 */
CREATE OR REPLACE FUNCTION hafah_backend.validate_operation_id(
    _operation_id    BIGINT
)
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  IF (SELECT ov.block_num FROM hive.operations_view ov WHERE ov.id = _operation_id) IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_operation_id(_operation_id);
  END IF;
END
$$;

RESET ROLE;
