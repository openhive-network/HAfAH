/*
Defined here are:
  - Function for parsing arguments
  - Repeated exception messages, used in hafah_endpoints.sql
*/

--SET ROLE hafah_owner;

DROP SCHEMA IF EXISTS hafah_backend CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_backend AUTHORIZATION hafah_owner;

GRANT USAGE ON SCHEMA hafah_backend TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_backend TO hafah_user;
GRANT USAGE ON SCHEMA hafah_python TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_python TO hafah_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hafah_python TO hafah_user;
GRANT USAGE ON SCHEMA hive TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hafah_user;

CREATE FUNCTION hafah_backend.parse_acc_hist_start(_start BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _start < 0 THEN
    9223372036854775807
  ELSE
    _start
  END;
END
$$
;

CREATE FUNCTION hafah_backend.parse_acc_hist_limit(_limit BIGINT)
RETURNS BIGINT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _limit < 0 THEN
    (2^32) + _limit
  ELSE
    _limit
  END;
END
$$
;

CREATE FUNCTION hafah_backend.parse_argument(_params JSON, _json_type TEXT, _arg_name TEXT, _arg_number INT, _is_bool BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __param TEXT;
BEGIN
  SELECT CASE WHEN _json_type = 'object' THEN
    _params->>_arg_name
  ELSE
    _params->>_arg_number
  END INTO __param;

  -- TODO: this is done to replicate behaviour of HAfAH python, might remove
  IF _is_bool IS TRUE AND __param ~ '([A-Z].+)' THEN
    RAISE invalid_text_representation;
  ELSE
    RETURN __param;
  END IF;
END
$$
;

CREATE FUNCTION hafah_backend.raise_exception(_code INT, _message TEXT, _data TEXT = NULL, _id JSON = NULL, _no_data BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    REPLACE(error_json::TEXT, ' :', ':')
  FROM json_build_object(
    'jsonrpc', '2.0',
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

CREATE FUNCTION hafah_backend.wrap_sql_exception(_exception_message TEXT, _id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32003, _exception_message, NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.raise_missing_arg(_arg_name TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32602, 'Invalid parameters', format('missing a required argument: ''%s''', _arg_name), _id);
END
$$
;

CREATE FUNCTION hafah_backend.raise_operation_id_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32602,'Invalid parameters','op_id cannot be None', _id);
END
$$
;

CREATE FUNCTION hafah_backend.raise_uint_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Parse Error:Couldn''t parse uint64_t', NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.raise_int_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Parse Error:Couldn''t parse int64_t', NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.raise_bool_case_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Bad Cast:Cannot convert string to bool (only "true" or "false" can be converted)', NULL, _id, TRUE);
END
$$
;

-- TODO: this is done to replicate behaviour of HAFAH python, change when possible
CREATE FUNCTION hafah_backend.raise_below_zero_acc_hist(_id JSON = NULL)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.wrap_sql_exception('Assert Exception:args.limit <= 1000: limit of 4294967295 is greater than maxmimum allowed', _id);
END
$$
;

CREATE FUNCTION hafah_backend.raise_invalid_char_in_hex(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, format('unspecified:Invalid hex character ''%s''', left(ltrim(_hex, '0123456789abcdefABCDEF'), 1)),  NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.raise_transaction_hash_invalid_length(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32003, format('Assert Exception:false: Transaction hash ''%s'' has invalid size. Transaction hash should have size of 160 bits', _hex), NULL, _id, TRUE);
END
$$
;

CREATE FUNCTION hafah_backend.raise_unknown_transaction(_hex TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32003, format('Assert Exception:false: Unknown Transaction %s', rpad(_hex, 40, '0')), NULL, _id, TRUE);
END
$$
;
