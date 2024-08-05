SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.operation_types:
  type: string
  enum:
    - virtual
    - real
    - all
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.operation_types CASCADE;
CREATE TYPE hafah_backend.operation_types AS ENUM (
    'virtual',
    'real',
    'all'
);
-- openapi-generated-code-end

/** openapi:paths
/blocks/{block-num}/operations:
  get:
    tags:
      - Blocks
    summary: Get operations in block
    description: |
      Returns all operations contained in a block.
      
      SQL example
      * `SELECT * FROM hafah_endpoints.get_ops_in_block(5000000);`

      REST call example      
      * `GET ''https://%1$s/hafah/blocks/5000000/operations''`
    operationId: hafah_endpoints.get_ops_in_block
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
          default: NULL
        description: Given block number
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
          default: NULL
        description: |
          A limit of retrieved operations per page,
          when not specified, the result contains all operations in block
      - in: query
        name: include-reversible
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If set to true also operations from reversible block will be included
          if block_num points to such block.
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
                        "type": "account_create_operation",
                        "value": {
                          "fee": {
                            "nai": "@@000000021",
                            "amount": "10000",
                            "precision": 3
                          },
                          "owner": {
                            "key_auths": [
                              [
                                "STM871wj5KKnbwwiRv3scVcxQ26ynPnE1uaZr6dPpqVu9F4zJZgjZ",
                                1
                              ]
                            ],
                            "account_auths": [],
                            "weight_threshold": 1
                          },
                          "active": {
                            "key_auths": [
                              [
                                "STM73bAnWEwkdUa7Lp4ovNzyu4soHUCaCNSz79YHQsDqscNdSe1E8",
                                1
                              ]
                            ],
                            "account_auths": [],
                            "weight_threshold": 1
                          },
                          "creator": "steem",
                          "posting": {
                            "key_auths": [
                              [
                                "STM7fXKrnQN3xhgFTQBFMgR9TU8CxfgAJrLvSDjGuM2bFkiuKfwZg",
                                1
                              ]
                            ],
                            "account_auths": [],
                            "weight_threshold": 1
                          },
                          "memo_key": "STM8i93Zznxu2QRNLCHBDXt5yyiMW1c3GEyVKV9XAs8H5wEWwdJaM",
                          "json_metadata": "",
                          "new_account_name": "kefadex"
                        }
                      },
                      "block": 5000000,
                      "trx_id": "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                      "op_in_trx": 0,
                      "timestamp": "2016-09-15T19:47:21",
                      "virtual_op": false,
                      "operation_id": "21474836480000009",
                      "trx_in_block": 0
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
                        "type": "limit_order_create_operation",
                        "value": {
                          "owner": "cvk",
                          "orderid": 1473968838,
                          "expiration": "2035-10-29T06:32:22",
                          "fill_or_kill": false,
                          "amount_to_sell": {
                            "nai": "@@000000021",
                            "amount": "10324",
                            "precision": 3
                          },
                          "min_to_receive": {
                            "nai": "@@000000013",
                            "amount": "6819",
                            "precision": 3
                          }
                        }
                      },
                      "block": 5000000,
                      "trx_id": "973290d26bac31335c000c7a3d3fe058ce3dbb9f",
                      "op_in_trx": 0,
                      "timestamp": "2016-09-15T19:47:21",
                      "virtual_op": false,
                      "operation_id": "21474836480000517",
                      "trx_in_block": 1
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
                  "next_operation_begin": 0
                }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_ops_in_block;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_ops_in_block(
    "block-num" INT = NULL,
    "operation-types" hafah_backend.operation_types = 'all',
    "operation-filter-low" NUMERIC = NULL,
    "operation-filter-high" NUMERIC = NULL,
    "operation-begin" BIGINT = -1,
    "page-size" INT = NULL,
    "include-reversible" BOOLEAN = False
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
  -- Required argument: block-num
  IF "block-num" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('block-num');
  END IF;

  IF "page-size" IS NULL THEN
    "page-size" := (POW(2, 31) - 1)::INT;
  END IF;

  BEGIN
    RETURN hafah_python.get_rest_ops_in_block_json(
      "block-num",
      __operation_types,
      hafah_python.numeric_to_bigint("operation-filter-low"),
      hafah_python.numeric_to_bigint("operation-filter-high"),
      "operation-begin",
      "page-size",
      "include-reversible",
      FALSE
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
