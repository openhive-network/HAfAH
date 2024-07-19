SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}/operations:
  get:
    tags:
      - Blocks
    summary: Get operations in block
    description: |
      Returns all operations contained in a block.
      
      SQL example
      * `SELECT * FROM hafah_endpoints.get_ops_in_block(213124);`

      * `SELECT * FROM hafah_endpoints.get_ops_in_block(5000000);`

      REST call example
      * `GET https://{hafah-host}/hafah/blocks/213124/operations`
      
      * `GET https://{hafah-host}/hafah/blocks/5000000/operations`
    operationId: hafah_endpoints.get_ops_in_block
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
          default: NULL
        description: 
      - in: query
        name: operation-begin
        required: false
        schema:
          type: integer
          x-sql-datatype: BIGINT
          default: -1
        description: Starting operation id
      - in: query
        name: page-size
        required: false
        schema:
          type: integer
          default: NULL
        description: |
          A limit of retrieved operations per page,
          when not specified, the result contains all operations in block
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
                      "op": {
                        "type": "producer_reward_operation",
                        "value": {
                          "producer": "initminer",
                          "vesting_shares": {
                            "nai": "@@000000021",
                            "amount": "1000",
                            "precision": 3
                          }
                        }
                      },
                      "block": 1000,
                      "trx_id": "0000000000000000000000000000000000000000",
                      "op_in_trx": 1,
                      "timestamp": "2016-03-24T16:55:30",
                      "virtual_op": true,
                      "operation_id": 4294967296064,
                      "trx_in_block": 4294967295
                    }
                  ],
                  "next_operation_begin": 0
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_ops_in_block;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_ops_in_block(
    "block-num" INT = NULL,
    "operation-begin" BIGINT = -1,
    "page-size" INT = NULL,
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
  -- Required argument: block-num
  IF "block-num" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('block-num', "id");
  END IF;

  IF "page-size" IS NULL THEN
    "page-size" := (POW(2, 31) - 1)::INT;
  END IF;

  BEGIN
    RETURN hafah_python.get_rest_ops_in_block_json("block-num", "operation-begin", "page-size", "only-virtual", "include-reversible", "is-legacy-style");
    EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END
$$
;

RESET ROLE;
