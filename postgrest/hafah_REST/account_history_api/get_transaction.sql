SET ROLE hafah_owner;

/** openapi:paths
/transactions/{transaction-id}:
  get:
    tags:
      - Transactions
    summary: Get transaction details
    description: |
      Returns the details of a transaction based on a transaction id (including their signatures,
      operations like also a block_num it was included to).
      
      SQL example
      * `SELECT * FROM hafah_rest.get_transaction('954f6de36e6715d128fa8eb5a053fc254b05ded0');`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0`
    operationId: hafah_rest.get_transaction
    parameters:
      - in: path
        name: transaction-id
        required: true
        schema:
          type: string
          default: NULL
        description: |
          trx_id of expected transaction
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
                  "ref_block_num": 36374,
                  "ref_block_prefix": 3218139339,
                  "expiration": "2018-04-09T00:29:06",
                  "operations": [
                    {
                      "type": "claim_reward_balance_operation",
                      "value": {
                        "account": "social",
                        "reward_hive": {
                          "amount": "0",
                          "precision": 3,
                          "nai": "@@000000021"
                        },
                        "reward_hbd": {
                          "amount": "0",
                          "precision": 3,
                          "nai": "@@000000013"
                        },
                        "reward_vests": {
                          "amount": "1",
                          "precision": 6,
                          "nai": "@@000000037"
                        }
                      }
                    }
                  ],
                  "extensions": [],
                  "signatures": [
                    "1b01bdbb0c0d43db821c09ae8a82881c1ce3ba0eca35f23bc06541eca05560742f210a21243e20d04d5c88cb977abf2d75cc088db0fff2ca9fdf2cba753cf69844"
                  ],
                  "transaction_id": "6fde0190a97835ea6d9e651293e90c89911f933c",
                  "block_num": 21401130,
                  "transaction_num": 25
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_transaction;
CREATE OR REPLACE FUNCTION hafah_rest.get_transaction(
    "transaction-id" TEXT = NULL,
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
    -- Required argument: transaction-id    
  IF NOT (translate("transaction-id", '0123456789abcdefABCDEF', '') = '') THEN
      RETURN hafah_backend.rest_raise_invalid_char_in_hex("transaction-id", "id");
  ELSEIF LENGTH("transaction-id") != 40 THEN
      RETURN hafah_backend.rest_raise_transaction_hash_invalid_length("transaction-id", "id");
  ELSEIF "transaction-id" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('transaction-id', "id");
  END IF;

  BEGIN
    RETURN hafah_python.get_transaction_json(decode("transaction-id", 'hex'), "include-reversible", "is-legacy-style");

    EXCEPTION
      WHEN invalid_text_representation THEN
        RETURN hafah_backend.rest_raise_uint_exception("id");
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END
$$
;

RESET ROLE;
