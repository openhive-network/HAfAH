/*
ah/api/hafah_backend.sql

Defined here are:
  - Function for parsing arguments
  - Functions for operation filters
  - Repeated exception messages, used in ah/api/hafah_api.sql and ah/api/hafah_objects.sql
*/

DROP SCHEMA IF EXISTS hafah_backend CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_backend;

-- python extension for operation filters
CREATE EXTENSION IF NOT EXISTS plpython3u SCHEMA pg_catalog;

CREATE OR REPLACE PROCEDURE hafah_backend.create_api_user()
LANGUAGE 'plpgsql'
AS $$
BEGIN
  --recreate role for reading data
  IF (SELECT 1 FROM pg_roles WHERE rolname='hafah_user') IS NOT NULL THEN
    DROP OWNED BY hafah_user;
  END IF;
  DROP ROLE IF EXISTS hafah_user;
  CREATE ROLE hafah_user;

  GRANT USAGE ON SCHEMA hafah_api TO hafah_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_api TO hafah_user;

  GRANT USAGE ON SCHEMA hafah_backend TO hafah_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_backend TO hafah_user;

  GRANT USAGE ON SCHEMA hafah_objects TO hafah_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_objects TO hafah_user;

  GRANT USAGE ON SCHEMA hafah_python TO hafah_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_python TO hafah_user;

  GRANT USAGE ON SCHEMA hive TO hafah_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hafah_user;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hafah_user;

  -- add ability for admin to switch to hafah_user role
  GRANT hafah_user TO haf_admin;

  -- add hafah schemas owner
  DROP ROLE IF EXISTS hafah_owner;
  CREATE ROLE hafah_owner;
  ALTER SCHEMA hafah_api OWNER TO hafah_owner;
  ALTER SCHEMA hafah_backend OWNER TO hafah_owner;
  ALTER SCHEMA hafah_objects OWNER TO hafah_owner;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.parse_argument(_params JSON, _json_type TEXT, _arg_name TEXT, _arg_number INT, _is_bool BOOLEAN = FALSE)
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

CREATE OR REPLACE FUNCTION hafah_backend.translate_filter(_input NUMERIC, _transform INT = 0)
RETURNS INT[]
LANGUAGE 'plpython3u'
AS
$$ 
  global _input
  if _input:
    _input = int(_input)
    __result = []
    for i in range(128):
      if _input & (1 << i):
        __result.append(i + _transform)
    return __result
  else:
    return None
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.create_filter_numeric(_operation_filter_low NUMERIC, _operation_filter_high NUMERIC)
RETURNS NUMERIC
LANGUAGE 'plpython3u'
AS
$$
  return (int(_operation_filter_high) << 64) | int(_operation_filter_low)
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_exception(_code INT, _message TEXT, _data TEXT = NULL, _id JSON = NULL, _no_data BOOLEAN = FALSE)
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

CREATE OR REPLACE FUNCTION hafah_backend.wrap_sql_exception(_exception_message TEXT, _id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32003, _exception_message, NULL, _id, TRUE);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_missing_arg(_arg_name TEXT, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32602, 'Invalid parameters', format('missing a required argument: ''%s''', _arg_name), _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_operation_id_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32602,'Invalid parameters','op_id cannot be None', _id);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_uint_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Parse Error:Couldn''t parse uint64_t', NULL, _id, TRUE);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_int_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Parse Error:Couldn''t parse int64_t', NULL, _id, TRUE);
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.raise_bool_case_exception(_id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_backend.raise_exception(-32000, 'Bad Cast:Cannot convert string to bool (only "true" or "false" can be converted)', NULL, _id, TRUE);
END
$$
;
