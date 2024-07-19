SET ROLE hafah_owner;

/** openapi:paths
/operations:
  get:
    tags:
      - Operations
    summary: Get operations in block range
    description: |
      Returns all operations contained in provided block range
      
      SQL example
      * `SELECT * FROM hafah_endpoints.get_operations(200,300);`

      REST call example
      * `GET https://{hafah-host}/hafah/operations?from-block=200&to-block=300`
    operationId: hafah_endpoints.get_operations
    parameters:
      - in: query
        name: from-block
        required: true
        schema:
          type: integer
          default: NULL
        description: 
      - in: query
        name: to-block
        required: true
        schema:
          type: integer
          default: NULL
        description: The distance between the blocks can be a maximum of 2000
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
          default: 1000
        description: |
          A limit of retrieved operations per page,
          up to 150000
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
                  "next_operation_begin": 0,
                  "next_block_range_begin": 1001
                }

      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_operations;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_operations(
    "from-block" INT = NULL,
    "to-block" INT = NULL,
    "operation-begin" BIGINT = -1,
    "page-size" INT = 1000,
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
    -- Required argument: to-block, from-block
  IF "from-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('from-block', "id");
  END IF;

  IF "to-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('to-block', "id");
  END IF;

  BEGIN
    RETURN hafah_python.get_rest_ops_in_blocks_json("from-block", "to-block", "operation-begin", "page-size", "only-virtual", "include-reversible", "is-legacy-style");
    EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END
$$
;

RESET ROLE;
