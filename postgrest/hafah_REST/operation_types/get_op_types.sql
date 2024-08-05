SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_endpoints.op_types:
  type: object
  properties:
    op_type_id:
      type: integer
      description: operation type id
    operation_name:
      type: string
      description: operation type name
    is_virtual:
      type: boolean
      description: true if operation is virtual
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_endpoints.op_types CASCADE;
CREATE TYPE hafah_endpoints.op_types AS (
    "op_type_id" INT,
    "operation_name" TEXT,
    "is_virtual" BOOLEAN
);
-- openapi-generated-code-end

/** openapi:components:schemas
hafah_endpoints.array_of_op_types:
  type: array
  items:
    $ref: '#/components/schemas/hafah_endpoints.op_types'
*/

/** openapi:paths
/operation-types:
  get:
    tags:
      - Operation-types
    summary: Lists operation types
    description: |
      Lookup optype ids for operations matching a partial operation name

      SQL example  
      * `SELECT * FROM hafah_endpoints.get_op_types(''author'');`

      REST call example
      * `GET ''https://%1$s/hafah/operation-types?input-value=author''`
    operationId: hafah_endpoints.get_op_types
    parameters:
      - in: query
        name: input-value
        required: false
        schema:
          type: string
          default: NULL
        description: parial name of operation
    responses:
      '200':
        description: |
          Operation type list, 
          if provided is `input-value` the list
          is limited to operations that partially match the `input-value`

          * Returns array of `hafah_endpoints.op_types`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_endpoints.array_of_op_types'
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
    "input-value" TEXT = NULL
)
RETURNS SETOF hafah_endpoints.op_types 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  __operation_name TEXT := NULL;
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);

  IF "input-value" IS NOT NULL THEN
    __operation_name := '%' || "input-value" || '%';
  END IF;  

  RETURN QUERY SELECT
    id::INT, split_part(name, '::', 3), is_virtual
  FROM hive.operation_types
  WHERE ((__operation_name IS NULL) OR (name LIKE __operation_name))
  ORDER BY id ASC
  ;

END
$$;

RESET ROLE;
