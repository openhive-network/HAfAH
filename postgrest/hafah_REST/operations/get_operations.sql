SET ROLE hafah_owner;

/** openapi:paths
/operations:
  get:
    tags:
      - Operations
    summary: Get operations in a block range
    description: |
      Returns all operations contained in specified block range, supports various forms of filtering.
      
      SQL example
      * `SELECT * FROM hafah_endpoints.get_operations(4999999,5000000);`

      REST call example
      * `GET ''https://%1$s/hafah-api/operations?from-block=4999999&to-block=5000000&operation-group-type=virtual''`
    operationId: hafah_endpoints.get_operations
    parameters:
      - in: query
        name: from-block
        required: true
        schema:
          type: string
          default: NULL
        description: |
          Lower limit of the block range, can be represented either by a block-number (integer) or a timestamp (in the format YYYY-MM-DD HH:MI:SS).

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is more than or equal to the given `timestamp` (i.e. `block''s created_at >= timestamp`).

          The function will interpret and convert the input based on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
      - in: query
        name: to-block
        required: true
        schema:
          type: string
          default: NULL
        description: | 
          Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). 

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).
          
          The function will convert the value depending on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
      - in: query
        name: operation-types
        required: false
        schema:
          type: string
          default: NULL
        description: |
          List of operations: if the parameter is empty, all operations will be included.
          example: `18,12`
      - in: query
        name: operation-group-type
        required: false
        schema:
          $ref: '#/components/schemas/hafah_backend.operation_group_types'
          default: all
        description: |
          filter operations by:

           * `virtual` - only virtual operations

           * `real` - only real operations

           * `all` - all operations
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
          If true, operations from reversible blocks will be included.
    responses:
      '200':
        description: |

          * Returns `hafah_backend.operations_in_block_range`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.operations_in_block_range'
            example: {
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
    "from-block" TEXT = NULL,
    "to-block" TEXT = NULL,
    "operation-types" TEXT = NULL,
    "operation-group-type" hafah_backend.operation_group_types = 'all',
    "operation-begin" BIGINT = -1,
    "page-size" INT = 1000,
    "include-reversible" BOOLEAN = False
)
RETURNS hafah_backend.operations_in_block_range 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  _block_range hive.blocks_range := hive.convert_to_blocks_range("from-block","to-block");
  _operation_types INT[] := (CASE WHEN "operation-types" IS NOT NULL THEN string_to_array("operation-types", ',')::INT[] ELSE NULL END);
  __exception_message TEXT;
  _operation_group_types BOOLEAN := (CASE WHEN "operation-group-type" = 'real' THEN FALSE WHEN "operation-group-type" = 'virtual' THEN TRUE ELSE NULL END);
BEGIN
  PERFORM hafah_python.validate_limit("page-size", 150000, 'page-size');
  PERFORM hafah_python.validate_negative_limit("page-size", 'page-size');
  PERFORM hafah_python.validate_block_range( _block_range.first_block, _block_range.last_block + 1, 2001);

  IF _block_range.last_block <= hive.app_get_irreversible_block() AND _block_range.last_block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

    -- Required argument: to-block, from-block
  IF _block_range.first_block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('from-block');
  END IF;

  IF _block_range.last_block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('to-block');
  END IF;

  RETURN hafah_backend.get_ops_in_blocks(
    _block_range.first_block,
    _block_range.last_block,
    _operation_group_types,
    _operation_types,
    "operation-begin",
    "page-size",
    "include-reversible",
    FALSE
  );

END
$$
;

RESET ROLE;
