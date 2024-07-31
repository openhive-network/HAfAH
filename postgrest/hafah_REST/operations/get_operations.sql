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
      * `SELECT * FROM hafah_endpoints.get_operations(4999999,5000000);`

      REST call example
      * `GET ''https://%1$s/hafah/operations?from-block=4999999&to-block=5000000&operation-types=virtual''`
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
        name: operation-types
        required: false
        schema:
          $ref: '#/components/schemas/hafah_backend.operation_types'
          default: all
        description: |
          filter operations by:

           * `virtual` - only virtual operations

           * `real` - only real operations

           * `all` - all operations
      - in: query
        name: operation-filter-low
        required: false
        schema:
          type: integer
          x-sql-datatype: NUMERIC
          default: NULL
        description: |
          The lower part of the bits of a 128-bit integer mask,
          where successive positions of bits set to 1 define which operation type numbers to return,
          expressed as a decimal number
      - in: query
        name: operation-filter-high
        required: false
        schema:
          type: integer
          x-sql-datatype: NUMERIC
          default: NULL
        description: |
          The higher part of the bits of a 128-bit integer mask,
          where successive positions of bits set to 1 define which operation type numbers to return,
          expressed as a decimal number
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
        name: include-reversible
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If set to true also operations from reversible block will be included
          if block_num points to such block.
      - in: query
        name: show-legacy-quantities
        required: false
        schema:
          type: boolean
          default: false
        description: Determines whether to show amounts in legacy style (as `10.000 HIVE`) or use NAI-style
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
                        "type": "effective_comment_vote_operation",
                        "value": {
                          "voter": "rkpl",
                          "author": "thedevil",
                          "weight": 0,
                          "rshares": -1383373254,
                          "permlink": "re-rkpl-how-to-make-a-good-picture-of-the-moon-my-guide-and-photos-20160915t193128824z",
                          "pending_payout": {
                            "nai": "@@000000013",
                            "amount": "0",
                            "precision": 3
                          },
                          "total_vote_weight": 590910411298246
                        }
                      },
                      "block": 4999999,
                      "trx_id": "9f4639be729f8ca436ac5bd01b5684cbc126d44d",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:18",
                      "virtual_op": true,
                      "operation_id": "21474832185033032",
                      "trx_in_block": 0
                    },
                    {
                      "op": {
                        "type": "limit_order_cancelled_operation",
                        "value": {
                          "seller": "cvk",
                          "orderid": 1473968539,
                          "amount_back": {
                            "nai": "@@000000021",
                            "amount": "9941",
                            "precision": 3
                          }
                        }
                      },
                      "block": 4999999,
                      "trx_id": "8f2a70dbe09902473eac39ffbd8ff626cb49bb51",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:18",
                      "virtual_op": true,
                      "operation_id": "21474832185033557",
                      "trx_in_block": 1
                    },
                    {
                      "op": {
                        "type": "pow_reward_operation",
                        "value": {
                          "reward": {
                            "nai": "@@000000037",
                            "amount": "5031442145",
                            "precision": 6
                          },
                          "worker": "smooth.witness"
                        }
                      },
                      "block": 4999999,
                      "trx_id": "a9596ee741bd4b4b7d3d8cadd15416bfe854209e",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:18",
                      "virtual_op": true,
                      "operation_id": "21474832185034062",
                      "trx_in_block": 2
                    },
                    {
                      "op": {
                        "type": "limit_order_cancelled_operation",
                        "value": {
                          "seller": "paco-steem",
                          "orderid": 1243424767,
                          "amount_back": {
                            "nai": "@@000000013",
                            "amount": "19276",
                            "precision": 3
                          }
                        }
                      },
                      "block": 4999999,
                      "trx_id": "b664e368d117e0b0d4b1b32325a18044f47b5ca5",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:18",
                      "virtual_op": true,
                      "operation_id": "21474832185034581",
                      "trx_in_block": 3
                    },
                    {
                      "op": {
                        "type": "producer_reward_operation",
                        "value": {
                          "producer": "smooth.witness",
                          "vesting_shares": {
                            "nai": "@@000000037",
                            "amount": "3003846056",
                            "precision": 6
                          }
                        }
                      },
                      "block": 4999999,
                      "trx_id": "0000000000000000000000000000000000000000",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:18",
                      "virtual_op": true,
                      "operation_id": "21474832185034816",
                      "trx_in_block": 4294967295
                    },
                    {
                      "op": {
                        "type": "account_created_operation",
                        "value": {
                          "creator": "steem",
                          "new_account_name": "kefadex",
                          "initial_delegation": {
                            "nai": "@@000000037",
                            "amount": "0",
                            "precision": 6
                          },
                          "initial_vesting_shares": {
                            "nai": "@@000000037",
                            "amount": "30038455132",
                            "precision": 6
                          }
                        }
                      },
                      "block": 5000000,
                      "trx_id": "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:21",
                      "virtual_op": true,
                      "operation_id": "21474836480000336",
                      "trx_in_block": 0
                    },
                    {
                      "op": {
                        "type": "producer_reward_operation",
                        "value": {
                          "producer": "ihashfury",
                          "vesting_shares": {
                            "nai": "@@000000037",
                            "amount": "3003845513",
                            "precision": 6
                          }
                        }
                      },
                      "block": 5000000,
                      "trx_id": "0000000000000000000000000000000000000000",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:47:21",
                      "virtual_op": true,
                      "operation_id": "21474836480000832",
                      "trx_in_block": 4294967295
                    }
                  ],
                  "next_operation_begin": 0,
                  "next_block_range_begin": 5000000
                }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_operations;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_operations(
    "from-block" INT = NULL,
    "to-block" INT = NULL,
    "operation-types" hafah_backend.operation_types = 'all',
    "operation-filter-low" NUMERIC = NULL,
    "operation-filter-high" NUMERIC = NULL,
    "operation-begin" BIGINT = -1,
    "page-size" INT = 1000,
    "include-reversible" BOOLEAN = False,
    "show-legacy-quantities" BOOLEAN = False
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __exception_message TEXT;
  __operation_types BOOLEAN := (CASE WHEN "operation-types" = 'real' THEN FALSE WHEN "operation-types" = 'virtual' THEN TRUE ELSE NULL END);
BEGIN
    -- Required argument: to-block, from-block
  IF "from-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('from-block');
  END IF;

  IF "to-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('to-block');
  END IF;

  BEGIN
    RETURN hafah_python.get_rest_ops_in_blocks_json(
      "from-block",
      "to-block",
      __operation_types,
      hafah_python.numeric_to_bigint("operation-filter-low"),
      hafah_python.numeric_to_bigint("operation-filter-high"),
      "operation-begin",
      "page-size",
      "include-reversible",
      "show-legacy-quantities"
    );
    EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.rest_wrap_sql_exception(__exception_message);
  END;
END
$$
;

RESET ROLE;
