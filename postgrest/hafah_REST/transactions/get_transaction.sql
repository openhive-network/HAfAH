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
      * `SELECT * FROM hafah_endpoints.get_transaction('954f6de36e6715d128fa8eb5a053fc254b05ded0');`

      REST call example
      * `GET https://{hafah-host}/hafah/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0`
    operationId: hafah_endpoints.get_transaction
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
                  "ref_block_num": 25532,
                  "ref_block_prefix": 3338687976,
                  "extensions": [],
                  "expiration": "2016-08-12T17:23:48",
                  "operations": [
                    {
                      "type": "custom_json_operation",
                      "value": {
                        "id": "follow",
                        "json": "{\"follower\":\"breck0882\",\"following\":\"steemship\",\"what\":[]}",
                        "required_auths": [],
                        "required_posting_auths": [
                          "breck0882"
                        ]
                      }
                    }
                  ],
                  "signatures": [
                    "201655190aac43bb272185c577262796c57e5dd654e3e491b9b32bd2d567c6d5de75185f221a38697d04d1a8e6a9deb722ec6d6b5d2f395dcfbb94f0e5898e858f"
                  ],
                  "transaction_id": "954f6de36e6715d128fa8eb5a053fc254b05ded0",
                  "block_num": 4023233,
                  "transaction_num": 0
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_transaction;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_transaction(
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
