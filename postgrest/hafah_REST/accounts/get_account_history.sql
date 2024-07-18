SET ROLE hafah_owner;

/** openapi:paths
/accounts/{account-name}/operations:
  get:
    tags:
      - Accounts
    summary: Get account's history
    description: |
      Returns a history of all operations for a given account.

      SQL example
      * `SELECT * FROM hafah_rest.get_account_history('blocktrades');`

      * `SELECT * FROM hafah_rest.get_account_history('gtg');`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/accounts/blocktrades/operations`
      
      * `GET https://{hafah-host}/hafah-rest/accounts/gtg/operations`
    operationId: hafah_rest.get_account_history
    parameters:
      - in: path
        name: account-name
        required: true
        schema:
          type: string
          default: NULL
        description: 
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
          default: NULL
        description:
      - in: query
        name: operation-filter-high
        required: false
        schema:
          type: integer
          default: NULL
        description: 
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
                  "history": [
                    [
                      4416,
                      {
                        "op": {
                          "type": "effective_comment_vote_operation",
                          "value": {
                            "voter": "gtg",
                            "author": "skypilot",
                            "weight": "19804864940707296",
                            "rshares": 87895502383,
                            "permlink": "sunset-at-point-sur-california",
                            "pending_payout": {
                              "nai": "@@000000013",
                              "amount": "14120",
                              "precision": 3
                            },
                            "total_vote_weight": "14379148533547713492"
                          }
                        },
                        "block": 4999982,
                        "trx_id": "fa7c8ac738b4c1fdafd4e20ee6ca6e431b641de3",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:46:24",
                        "virtual_op": true,
                        "operation_id": 0,
                        "trx_in_block": 0
                      }
                    ]
                  ]
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_account_history;
CREATE OR REPLACE FUNCTION hafah_rest.get_account_history(
    "account-name" TEXT = NULL,
    "start" INT = -1,
    "result-limit" INT = 1000,
    "include-reversible" BOOLEAN = False,
    "operation-filter-low" INT = NULL,
    "operation-filter-high" INT = NULL,
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
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  
    -- Required argument: account-name
  IF "account-name" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('account-name', "id");
  ELSE
      IF LENGTH("account-name") > 16 THEN
      RETURN hafah_backend.rest_raise_account_name_too_long("account-name", "id");
      END IF;
  END IF;

  IF "result-limit" < 0 THEN
      RETURN hafah_backend.rest_raise_below_zero_acc_hist("id");
  END IF;

  BEGIN
    RETURN hafah_python.ah_get_account_history_json(
      "operation-filter-low",
      "operation-filter-high",
      "account-name",
      hafah_backend.parse_acc_hist_start("start"),
      hafah_backend.parse_acc_hist_limit("result-limit"),
      "include-reversible",
      "is-legacy-style"
      );
    EXCEPTION
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END;
$$
;

RESET ROLE;
