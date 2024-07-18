SET ROLE hafah_owner;

CREATE FUNCTION hafah_backend.rest_raise_exception(_code INT, _message TEXT, _data TEXT = NULL, _id INT = 1, _no_data BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'error',
    CASE WHEN _no_data IS TRUE THEN
      json_build_object(
        'code', _code,
        'message', _message
      )
    ELSE
      json_build_object(
        'code', _code,
        'message', _message,
        'data', _data
      )
    END,
    'id', _id
  ) error_json;
END
$$
;

CREATE FUNCTION hafah_backend.rest_wrap_sql_exception(_exception_message TEXT, _id INT = 1)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32003, _exception_message, NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_missing_arg(_arg_name TEXT, _id INT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32602, 'Invalid parameters', format('missing a required argument: ''%s''', _arg_name), _id);
END
$$
;

CREATE FUNCTION hafah_backend.raise_uint_exception(_id INT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32000, 'Parse Error:Couldn''t parse uint64_t', NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_account_name_too_long(_account_name TEXT, _id INT)
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
    ),
    NULL,
    _id,
    TRUE
  );
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_below_zero_acc_hist(_id INT = 1)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_wrap_sql_exception('Assert Exception:args.limit <= 1000: limit of 4294967295 is greater than maxmimum allowed', _id);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_invalid_char_in_hex(_hex TEXT, _id INT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32000, format('unspecified:Invalid hex character ''%s''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1)),  NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.rest_raise_transaction_hash_invalid_length(_hex TEXT, _id INT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.rest_raise_exception(-32003, format('Assert Exception:false: Transaction hash ''%s'' has invalid size. Transaction hash should have size of 160 bits', _hex), NULL, _id, TRUE);
END
$$
;

RESET ROLE;
