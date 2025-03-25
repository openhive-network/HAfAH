SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.array_of_op_types:
  type: array
  items:
    $ref: '#/components/schemas/hafah_backend.op_types'
*/

/** openapi:paths
/operation-types:
  get:
    tags:
      - Operation-types
    summary: Lookup operation type ids for operations matching a partial operation name.
    description: |
      Lookup operation type ids for operations matching a partial operation name.

      SQL example  
      * `SELECT * FROM hafah_endpoints.get_op_types(''author'');`

      REST call example
      * `GET ''https://%1$s/hafah-api/operation-types?partial-operation-name=author''`
    operationId: hafah_endpoints.get_op_types
    parameters:
      - in: query
        name: partial-operation-name
        required: false
        schema:
          type: string
          default: NULL
        description: parial name of operation
    responses:
      '200':
        description: |
          Operation type list, 
          if `partial-operation-name` is provided then the list
          is limited to operations that partially match the `partial-operation-name`

          * Returns array of `hafah_backend.op_types`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.array_of_op_types'
            example:
              - op_type_id: 51
                operation_name: author_reward_operation
                is_virtual: true
      '404':
        description: No operations in the database
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_op_types;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_op_types(
    "partial-operation-name" TEXT = NULL
)
RETURNS SETOF hafah_backend.op_types 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  __operation_name TEXT := '%' || "partial-operation-name" || '%';
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);

  RETURN QUERY (
    SELECT
      op_type_id,
      operation_name,
      is_virtual
    FROM hafah_backend.get_op_types(__operation_name)
  );
END
$$;

RESET ROLE;
