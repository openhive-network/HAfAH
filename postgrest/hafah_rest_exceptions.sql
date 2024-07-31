SET ROLE hafah_owner;

CREATE FUNCTION hafah_backend.rest_raise_exception(_code INT, _message TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'code', _code,
    'message', _message
  ) error_json;
END
$$
;

CREATE FUNCTION hafah_backend.rest_wrap_sql_exception(_exception_message TEXT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32003, _exception_message);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_missing_arg(_arg_name TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32602, 'Invalid parameters', format('missing a required argument: ''%s''', _arg_name));
END
$$
;

CREATE FUNCTION hafah_backend.raise_uint_exception()
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32000, 'Parse Error:Couldn''t parse uint64_t');
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_account_name_too_long(_account_name TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(
    -32003,
    format(
      'Assert Exception:in_len <= sizeof(data): Input too large: `%s` (%s) for fixed size string: (16)',
      _account_name,
      LENGTH(_account_name)
    )
  );
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_below_zero_acc_hist()
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_wrap_sql_exception('Assert Exception:args.limit <= 1000: limit of 4294967295 is greater than maxmimum allowed');
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_invalid_char_in_hex(_hex TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32000, format('unspecified:Invalid hex character ''%s''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1)));
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_transaction_hash_invalid_length(_hex TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32003, format('Assert Exception:false: Transaction hash ''%s'' has invalid size. Transaction hash should have size of 160 bits', _hex));
END
$$
;

RESET ROLE;
