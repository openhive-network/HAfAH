SET ROLE hafah_owner;

/** openapi:paths
/accounts/{account-name}/operations:
  get:
    tags:
      - Accounts
    summary: Get account''s history
    description: |
      Returns a history of all operations for a given account.

      SQL example
      * `SELECT * FROM hafah_endpoints.get_account_history(''blocktrades'');`

      REST call example
      * `GET ''https://%1$s/hafah/accounts/blocktrades/operations?result-limit=3''`
    operationId: hafah_endpoints.get_account_history
    parameters:
      - in: path
        name: account-name
        required: true
        schema:
          type: string
          default: NULL
        description: given account name
      - in: query
        name: start
        required: false
        schema:
          type: integer
          default: -1
        description: |
          e.g.: -1 for reverse history or any positive numeric
      - in: query
        name: result-limit
        required: false
        schema:
          type: integer
          default: 1000
        description: up to 1000
      - in: query
        name: include-reversible
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If set to true also operations from reversible block will be included
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
              - [
                  [
                    219864,
                    {
                      "op": {
                        "type": "producer_reward_operation",
                        "value": {
                          "producer": "blocktrades",
                          "vesting_shares": {
                            "nai": "@@000000037",
                            "amount": "3003868105",
                            "precision": 6
                          }
                        }
                      },
                      "block": 4999959,
                      "trx_id": "0000000000000000000000000000000000000000",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:45:12",
                      "virtual_op": true,
                      "operation_id": "21474660386343488",
                      "trx_in_block": 4294967295
                    }
                  ],
                  [
                    219865,
                    {
                      "op": {
                        "type": "producer_reward_operation",
                        "value": {
                          "producer": "blocktrades",
                          "vesting_shares": {
                            "nai": "@@000000037",
                            "amount": "3003850165",
                            "precision": 6
                          }
                        }
                      },
                      "block": 4999992,
                      "trx_id": "0000000000000000000000000000000000000000",
                      "op_in_trx": 1,
                      "timestamp": "2016-09-15T19:46:57",
                      "virtual_op": true,
                      "operation_id": "21474802120262208",
                      "trx_in_block": 4294967295
                    }
                  ],
                  [
                    219866,
                    {
                      "op": {
                        "type": "transfer_operation",
                        "value": {
                          "to": "blocktrades",
                          "from": "mrwang",
                          "memo": "a79c09cd-0084-4cd4-ae63-bf6d2514fef9",
                          "amount": {
                            "nai": "@@000000013",
                            "amount": "1633",
                            "precision": 3
                          }
                        }
                      },
                      "block": 4999997,
                      "trx_id": "e75f833ceb62570c25504b55d0f23d86d9d76423",
                      "op_in_trx": 0,
                      "timestamp": "2016-09-15T19:47:12",
                      "virtual_op": false,
                      "operation_id": "21474823595099394",
                      "trx_in_block": 3
                    }
                  ]
                ]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_account_history;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_account_history(
    "account-name" TEXT = NULL,
    "start" INT = -1,
    "result-limit" INT = 1000,
    "include-reversible" BOOLEAN = False,
    "operation-filter-low" NUMERIC = NULL,
    "operation-filter-high" NUMERIC = NULL,
    "show-legacy-quantities" BOOLEAN = False
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __exception_message TEXT;
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  
    -- Required argument: account-name
  IF "account-name" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('account-name');
  ELSE
      IF LENGTH("account-name") > 16 THEN
      RETURN hafah_backend.rest_raise_account_name_too_long("account-name");
      END IF;
  END IF;

  IF "result-limit" < 0 THEN
      RETURN hafah_backend.rest_raise_below_zero_acc_hist();
  END IF;

  BEGIN
    RETURN hafah_python.get_account_history_json(
      "operation-filter-low",
      "operation-filter-high",
      "account-name",
      hafah_backend.parse_acc_hist_start("start"),
      hafah_backend.parse_acc_hist_limit("result-limit"),
      "include-reversible",
      "show-legacy-quantities"
      );
    EXCEPTION
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message);
  END;
END;
$$
;

RESET ROLE;
