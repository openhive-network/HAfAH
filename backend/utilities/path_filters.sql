SET ROLE hafah_owner;

/*
 * path_filters.sql: JSON path filtering utilities.
 *
 * Functions:
 *   - hafah_backend.decode_param() - Decode base64 encoded parameter
 *   - hafah_backend.parse_path_filters() - Parse path filter parameters
 */

/*
 * ===================================================================================
 * decode_param
 * ===================================================================================
 * PURPOSE: Decodes a base64 encoded parameter to UTF-8 text.
 *
 * PARAMETERS:
 *   _encoded_param - Base64 encoded string
 *
 * RETURNS: TEXT - decoded string
 */
CREATE OR REPLACE FUNCTION hafah_backend.decode_param(
    _encoded_param    TEXT
)
RETURNS TEXT
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN convert_from(decode(_encoded_param, 'base64'), 'UTF8');
END
$$;

/*
 * ===================================================================================
 * parse_path_filters
 * ===================================================================================
 * PURPOSE: Parses an array of base64-encoded path filter parameters into structured
 *          JSONB key paths and text values. Each parameter has format "key.path=value".
 *
 * PARAMETERS:
 *   _params - Array of base64-encoded filter parameters
 *
 * RETURNS: TABLE with:
 *   - param_json: JSONB array of key path arrays
 *   - param_text: TEXT array of corresponding values
 */
CREATE OR REPLACE FUNCTION hafah_backend.parse_path_filters(
    _params    TEXT[]
)
RETURNS TABLE(param_json JSONB, param_text TEXT[])
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __json_list JSONB := '[]'::JSONB;
  __text_list TEXT[] := '{}';
  __param TEXT;
  __param_text TEXT;
  __key_value TEXT;
  __key_part TEXT[];
  __value_part TEXT;
BEGIN
  FOREACH __param IN ARRAY _params
  LOOP
    -- Remove ""
    __param_text := hafah_backend.decode_param(__param);
    -- Extract everything before the first '=' as key
    __key_value := split_part(__param_text, '=', 1);

    -- Extract everything after the first '=' as value
    __value_part := replace(__param_text, __key_value || '=', '');

    -- Split the key into parts based on '.' separator
    __key_part := string_to_array(__key_value, '.');

    -- Append key parts to the JSONB list
    __json_list := __json_list || jsonb_build_array(__key_part);

    -- Append the entire value part to the text array
    __text_list := array_append(__text_list, __value_part);
  END LOOP;

  RETURN QUERY SELECT __json_list, __text_list;
END
$$;

RESET ROLE;
