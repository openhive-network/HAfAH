SET ROLE hafah_owner;

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
