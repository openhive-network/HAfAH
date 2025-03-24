SET ROLE hafah_owner;

CREATE FUNCTION hafah_backend.rest_raise_missing_account(_account_name TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:Account ''%s'' does not exist', _account_name;
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_missing_arg(_account_name TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:Missing a required argument: ''%s''', _arg_name;
END
$$
;

CREATE FUNCTION hafah_backend.raise_uint_exception()
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:Couldn''t parse uint64_t';
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_account_name_too_long(_account_name TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:in_len <= sizeof(data): Input too large: `%s` (%s) for fixed size string: (16)', _account_name, LENGTH(_account_name);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_invalid_char_in_hex(_hex TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:Invalid hex character ''%s''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_transaction_hash_invalid_length(_hex TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION 'Assert Exception:false: Transaction hash ''%s'' has invalid size. Transaction hash should have size of 160 bits', _hex;
END
$$
;

RESET ROLE;
