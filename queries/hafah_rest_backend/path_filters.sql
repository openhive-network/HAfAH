SET ROLE hafah_owner;


-- Function used in body returning functions that allows to limit too long operation_body (small.minion), allows FE to set desired length of operation
-- Too long operations are being replaced by placeholder with possibility of opening it in another page
DROP TYPE IF EXISTS hafah_backend.operation_body_filter_result CASCADE; -- noqa: LT01
CREATE TYPE hafah_backend.operation_body_filter_result AS (
    body JSONB,
    id TEXT,
    is_modified BOOLEAN
);

CREATE OR REPLACE FUNCTION hafah_backend.operation_body_filter(_body JSONB, _op_id BIGINT, _body_limit INT = 2147483647)
RETURNS hafah_backend.operation_body_filter_result -- noqa: LT01, CP05
LANGUAGE 'plpgsql'
STABLE
AS
$$
DECLARE
    _result hafah_backend.operation_body_filter_result := (_body, _op_id, FALSE);
BEGIN
    IF length(_body::TEXT) > _body_limit THEN
        _result.body := jsonb_build_object(
            'type', 'body_placeholder_operation', 
            'value', jsonb_build_object(
                'org-op-id', _op_id::TEXT, 
                'org-operation_type', _body->>'type', 
                'truncated_body', 'body truncated up to specified limit just for presentation purposes'
            )
        );
        _result.is_modified := TRUE;
    END IF;

    RETURN _result;
END
$$;

CREATE OR REPLACE FUNCTION hafah_backend.decode_param(_encoded_param TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql' 
STABLE
AS 
$$
BEGIN
  RETURN convert_from(decode(_encoded_param, 'base64'), 'UTF8');
END
$$;

CREATE OR REPLACE FUNCTION hafah_backend.parse_path_filters(_params TEXT[])
RETURNS TABLE(param_json JSONB, param_text TEXT[]) 
LANGUAGE 'plpgsql' 
STABLE
AS 
$$
DECLARE
  json_list JSONB := '[]'::JSONB;
  text_list TEXT[] := '{}';
  param TEXT;
  param_text TEXT;
  key_value TEXT;
  key_part TEXT[];
  value_part TEXT;
BEGIN
  FOREACH param IN ARRAY _params
  LOOP
    -- Remove "" 
    param_text := hafah_backend.decode_param(param);
    -- Extract everything before the first '=' as key
    key_value := split_part(param_text, '=', 1);

    -- Extract everything after the first '=' as value
    value_part := replace(param_text,key_value || '=','');

    -- Split the key into parts based on '.' separator
    key_part := string_to_array(key_value, '.');

    -- Append key parts to the JSONB list
    json_list := json_list || jsonb_build_array(key_part);

    -- Append the entire value part to the text array
    text_list := array_append(text_list, value_part);
  END LOOP;

  RETURN QUERY SELECT json_list, text_list;
END
$$;

RESET ROLE;
