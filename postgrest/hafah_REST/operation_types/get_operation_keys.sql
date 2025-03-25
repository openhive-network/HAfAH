SET ROLE hafah_owner;

/** openapi:paths
/operation-types/{type-id}/keys:
  get:
    tags:
      - Operation-types
    summary: Returns key names for an operation type.
    description: |
      Returns json body keys for an operation type

      SQL example
      * `SELECT * FROM hafah_endpoints.get_operation_keys(1);`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/operation-types/1/keys''`
    operationId: hafah_endpoints.get_operation_keys
    parameters:
      - in: path
        name: type-id
        required: true
        schema:
          type: integer
        description: Unique operation type identifier 
    responses:
      '200':
        description: |
          Operation json key paths

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: array
              items:
                type: array
                items:
                  type: string
              x-sql-datatype: JSON
            example: [
                  ["value","body"],
                  ["value","title"],
                  ["value","author"],
                  ["value","permlink"],
                  ["value","json_metadata"],
                  ["value","parent_author"],
                  ["value","parent_permlink"]
                ]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_operation_keys;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_operation_keys(
    "type-id" INT
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET enable_bitmapscan = OFF
-- enable_bitmapscan = OFF helps with perfomance on database with smaller number of blocks 
-- (tested od 12m blocks, planner choses wrong plan and the query is slow)
AS
$$
DECLARE
	_example_key JSON := (SELECT ov.body FROM hive.operations_view ov WHERE ov.op_type_id = "type-id" LIMIT 1);
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);

  IF ("type-id" > (SELECT MAX(id) FROM hafd.operation_types)) OR "type-id" < 0 THEN
    PERFORM hafah_backend.rest_raise_missing_op_type("type-id");
  END IF;

  RETURN COALESCE(
    (
      WITH RECURSIVE extract_keys AS (
        SELECT 
          ARRAY['value']::TEXT[] as key_path, 
          (json_each(_example_key -> 'value')).*
        UNION ALL
        SELECT 
          key_path || key,
          (json_each(value)).*
        FROM 
          extract_keys
        WHERE 
          json_typeof(value) = 'object'
      )
      SELECT 
        json_agg(to_json(key_path || key))
      FROM 
        extract_keys
      WHERE 
        json_typeof(value) != 'object'
    ), '[]'::json
  );
END
$$;

RESET ROLE;
