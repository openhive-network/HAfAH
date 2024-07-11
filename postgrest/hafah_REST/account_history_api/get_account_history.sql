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
        name: limit
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
                      99,
                      {
                        "trx_id": "0000000000000000000000000000000000000000",
                        "block": 0,
                        "trx_in_block": 4294967295,
                        "op_in_trx": 0,
                        "virtual_op": 0,
                        "timestamp": "2019-12-09T21:32:39",
                        "op": {}
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
    "limit" INT = 1000,
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
    -- Required argument: account-name
  IF "account-name" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('account-name', "id");
  ELSE
      IF LENGTH("account-name") > 16 THEN
      RETURN hafah_backend.rest_raise_account_name_too_long("account-name", "id");
      END IF;
  END IF;

  IF "limit" < 0 THEN
      RETURN hafah_backend.rest_raise_below_zero_acc_hist("id");
  END IF;

  BEGIN
    RETURN hafah_python.ah_get_account_history_json(
      "operation-filter-low",
      "operation-filter-high",
      "account-name",
      hafah_backend.parse_acc_hist_start("start"),
      hafah_backend.parse_acc_hist_limit("limit"),
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
