SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_account(_account_name TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'Account ''%'' does not exist', _account_name;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_block(_block_num INT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'Block_num ''%'' does not exist', _block_num;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_missing_arg(_account_name TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'Missing a required argument: ''%''', _arg_name;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_uint_exception()
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'Couldn''t parse uint64_t';
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_account_name_too_long(_account_name TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'in_len <= sizeof(data): Input too large: `%` (%) for fixed size string: (16)', _account_name, LENGTH(_account_name);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_invalid_char_in_hex(_hex TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'Invalid hex character ''%''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.rest_raise_transaction_hash_invalid_length(_hex TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RAISE EXCEPTION 'false: Transaction hash ''%'' has invalid size. Transaction hash should have size of 160 bits', _hex;
END
$$
;

RESET ROLE;
