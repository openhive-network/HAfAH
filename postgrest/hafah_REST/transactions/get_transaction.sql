SET ROLE hafah_owner;

/** openapi:paths
/transactions/{transaction-id}:
  get:
    tags:
      - Transactions
    summary: Lookup a transaction''s details from its transaction id.
    description: |
      Returns the details of a transaction based on a transaction id (including its signatures,
      operations, and containing block number).
      
      SQL example
      * `SELECT * FROM hafah_endpoints.get_transaction(''954f6de36e6715d128fa8eb5a053fc254b05ded0'');`

      REST call example
      * `GET ''https://%1$s/hafah-api/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0''`
    operationId: hafah_endpoints.get_transaction
    parameters:
      - in: path
        name: transaction-id
        required: true
        schema:
          type: string
        description: transaction id of transaction to look up
      - in: query
        name: include-virtual
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If true, virtual operations will be included.
    responses:
      '200':
        description: |
          The transaction body

          * Returns `hafah_backend.transaction`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.transaction'
            example: {
              "transaction_json": {
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
                ]
              },
              "transaction_id": "954f6de36e6715d128fa8eb5a053fc254b05ded0",
              "block_num": 4023233,
              "transaction_num": 0,
              "timestamp": "2016-08-12T17:23:39"
            }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_transaction;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_transaction(
    "transaction-id" TEXT,
    "include-virtual" BOOLEAN = False
)
RETURNS hafah_backend.transaction 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  _transaction_type hafah_backend.transaction ;
BEGIN
  WITH select_transaction AS MATERIALIZED 
  (
    SELECT 
      transaction_json::JSON,
      bv.created_at
    FROM hafah_python.get_transaction_json(
      ('\x' || "transaction-id")::BYTEA, 
      TRUE, 
      FALSE, 
      "include-virtual"
    ) AS transaction_json
    JOIN hive.blocks_view bv ON bv.num = (transaction_json->>'block_num')::INT
  )
  SELECT
    (
      json_build_object(
        'ref_block_num', (transaction_json->>'ref_block_num')::BIGINT,
        'ref_block_prefix',(transaction_json->>'ref_block_prefix')::BIGINT,
        'extensions', (transaction_json->>'extensions')::JSON,
        'expiration', (transaction_json->>'expiration')::TEXT,
        'operations', (transaction_json->>'operations')::JSON,
        'signatures', (transaction_json->>'signatures')::JSON
      ),
      (transaction_json->>'transaction_id')::TEXT,
      (transaction_json->>'block_num')::INT,
      (transaction_json->>'transaction_num')::INT,
      (created_at)::TIMESTAMP
    )::hafah_backend.transaction
  INTO _transaction_type
  FROM select_transaction;
  
  IF _transaction_type.block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  RETURN _transaction_type;
END
$$;

RESET ROLE;
