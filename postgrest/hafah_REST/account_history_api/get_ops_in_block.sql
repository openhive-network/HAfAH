SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}/operations:
  get:
    tags:
      - Blocks
    summary: Get operations in blocks
    description: |
      Returns all operations contained in a block.
      
      SQL example
      * `SELECT * FROM hafah_rest.get_ops_in_block(213124);`

      * `SELECT * FROM hafah_rest.get_ops_in_block(5000000);`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/blocks/213124/operations`
      
      * `GET https://{hafah-host}/hafah-rest/blocks/5000000/operations`
    operationId: hafah_rest.get_ops_in_block
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
          default: 0
        description: 
      - in: query
        name: only-virtual
        required: false
        schema:
          type: boolean
          default: false
        description: 
      - in: query
        name: include-reversible
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If set to true also operations from reversible block will be included
          if block_num points to such block.
      - in: query
        name: is-legacy-style
        required: false
        schema:
          type: boolean
          default: false
        description:
      - in: query
        name: id
        required: false
        schema:
          type: integer
          default: 1
        description: 
    responses:
      '200':
        description: |

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSON
            example: 
              - {
                  "ops": [
                    {
                      "trx_id": "0000000000000000000000000000000000000000",
                      "block": 0,
                      "trx_in_block": 4294967295,
                      "op_in_trx": 0,
                      "virtual_op": 0,
                      "timestamp": "2019-10-06T09:05:15",
                      "op": {}
                    }
                  ]
                }

      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_ops_in_block;
CREATE OR REPLACE FUNCTION hafah_rest.get_ops_in_block(
    "block-num" INT = 0,
    "only-virtual" BOOLEAN = False,
    "include-reversible" BOOLEAN = False,
    "is-legacy-style" BOOLEAN = False,
    "id" INT = 1
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __exception_message TEXT;
BEGIN
    BEGIN
        RETURN hafah_python.get_ops_in_block_json("block-num", "only-virtual", "include-reversible", "is-legacy-style");
        EXCEPTION
        WHEN raise_exception THEN
            GET STACKED DIAGNOSTICS __exception_message = message_text;
            RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
    END;
END
$$
;

RESET ROLE;
