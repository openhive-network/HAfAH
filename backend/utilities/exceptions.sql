SET ROLE hafah_owner;

/*
 * exceptions.sql: Exception handling functions for REST and JSON-RPC APIs.
 *
 * REST Exceptions:
 *   - hafah_backend.rest_raise_missing_account() - Account not found
 *   - hafah_backend.rest_raise_missing_block() - Block not found
 *   - hafah_backend.rest_raise_missing_op_type() - Operation type not found
 *   - hafah_backend.rest_raise_missing_operation_id() - Operation ID not found
 *   - hafah_backend.rest_raise_missing_arg() - Required argument missing
 *   - hafah_backend.rest_raise_account_name_too_long() - Account name exceeds limit
 *   - hafah_backend.rest_raise_invalid_char_in_hex() - Invalid hex character
 *   - hafah_backend.rest_raise_transaction_hash_invalid_length() - Invalid transaction hash length
 *   - hafah_backend.rest_raise_invalid_operation_types() - Invalid operation types
 *   - hafah_backend.rest_raise_invalid_participation() - Invalid participation mode
 *
 * Shared Exceptions:
 *   - hafah_backend.raise_uint_exception() - Failed to parse uint64
 */

-- ===================================================================================
-- REST EXCEPTIONS
-- ===================================================================================

/*
 * ===================================================================================
 * rest_raise_missing_account
 * ===================================================================================
 * PURPOSE: Raises an exception when the specified account does not exist.
 *
 * PARAMETERS:
 *   _account_name - Name of the account that was not found
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_account(
    _account_name    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Account ''%'' does not exist', _account_name;
END
$$;

/*
 * ===================================================================================
 * rest_raise_missing_block
 * ===================================================================================
 * PURPOSE: Raises an exception when the specified block does not exist.
 *
 * PARAMETERS:
 *   _block_num - Block number that was not found
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_block(
    _block_num    INT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Block_num ''%'' does not exist', _block_num;
END
$$;

/*
 * ===================================================================================
 * rest_raise_missing_op_type
 * ===================================================================================
 * PURPOSE: Raises an exception when the specified operation type ID does not exist.
 *
 * PARAMETERS:
 *   _id - Operation type ID that was not found
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_op_type(
    _id    INT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'op_type_id ''%'' does not exist', _id;
END
$$;

/*
 * ===================================================================================
 * rest_raise_missing_operation_id
 * ===================================================================================
 * PURPOSE: Raises an exception when the specified operation ID does not exist.
 *
 * PARAMETERS:
 *   _id - Operation ID that was not found
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_operation_id(
    _id    BIGINT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Operation_id ''%'' does not exist', _id;
END
$$;

/*
 * ===================================================================================
 * rest_raise_missing_arg
 * ===================================================================================
 * PURPOSE: Raises an exception when a required argument is missing.
 *
 * PARAMETERS:
 *   _arg_name - Name of the missing argument
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_arg(
    _arg_name    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Missing a required argument: ''%''', _arg_name;
END
$$;

/*
 * ===================================================================================
 * rest_raise_account_name_too_long
 * ===================================================================================
 * PURPOSE: Raises an exception when an account name exceeds the maximum length.
 *
 * PARAMETERS:
 *   _account_name - Account name that is too long
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_account_name_too_long(
    _account_name    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'in_len <= sizeof(data): Input too large: `%` (%) for fixed size string: (16)', _account_name, LENGTH(_account_name);
END
$$;

/*
 * ===================================================================================
 * rest_raise_invalid_char_in_hex
 * ===================================================================================
 * PURPOSE: Raises an exception when an invalid character is found in a hex string.
 *
 * PARAMETERS:
 *   _hex - Hex string containing invalid character
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_invalid_char_in_hex(
    _hex    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Invalid hex character ''%''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1);
END
$$;

/*
 * ===================================================================================
 * rest_raise_transaction_hash_invalid_length
 * ===================================================================================
 * PURPOSE: Raises an exception when a transaction hash has an invalid length.
 *
 * PARAMETERS:
 *   _hex - Transaction hash with invalid length
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_transaction_hash_invalid_length(
    _hex    TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'false: Transaction hash ''%'' has invalid size. Transaction hash should have size of 160 bits', _hex;
END
$$;

/*
 * ===================================================================================
 * rest_raise_invalid_operation_types
 * ===================================================================================
 * PURPOSE: Raises an exception when invalid operation type IDs are provided.
 *
 * PARAMETERS:
 *   _allowed_operations - Array of allowed operation IDs
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_invalid_operation_types(
    _allowed_operations    INT[]
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Invalid operation ID detected. Allowed IDs are: %', _allowed_operations;
END
$$;

/*
 * ===================================================================================
 * rest_raise_invalid_participation
 * ===================================================================================
 * PURPOSE: Raises an exception when participation mode 'all' is used with an account name.
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_invalid_participation()
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'For participation mode ''all'', account name should not be provided';
END
$$;

-- ===================================================================================
-- SHARED EXCEPTIONS
-- ===================================================================================

/*
 * ===================================================================================
 * raise_uint_exception
 * ===================================================================================
 * PURPOSE: Raises an exception when a uint64 value cannot be parsed.
 *
 * RETURNS: VOID (always raises exception)
 */
CREATE OR REPLACE FUNCTION hafah_backend.raise_uint_exception()
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RAISE EXCEPTION 'Couldn''t parse uint64_t';
END
$$;

RESET ROLE;
