/*
 * get_operation: REST endpoint for single operation lookup by ID.
 *
 * ENDPOINT: GET /operations/{operation-id}
 *
 * PURPOSE: Retrieve a single operation's full details by its unique ID.
 *
 * PARAMETERS:
 *   operation-id (path) - 64-bit operation identifier [REQUIRED]
 *                         Encodes block_num (32 bits) + op_pos (24 bits) + type (8 bits)
 *
 * OPERATION ID ENCODING:
 *   msb.....................lsb
 *    || block | op_pos | type ||
 *    ||  32b  |  24b   |  8b  ||
 *
 * RETURNS: Operation details including:
 *   - op (operation body with type and value)
 *   - block, trx_id, op_pos, op_type_id, timestamp
 *   - virtual_op (boolean), operation_id, trx_in_block
 *
 * CACHING:
 *   - 1 year cache if operation is in an irreversible block
 *   - 2 second cache if operation is in a reversible block
 *
 * DELEGATES TO: hafah_backend.get_operation()
 */
SET ROLE hafah_owner;

/** openapi:paths
/operations/{operation-id}:
  get:
    tags:
      - Operations
    summary: lookup an operation by its id.
    description: |
      Get operation''s body and its extended parameters

      SQL example
      * `SELECT * FROM hafah_endpoints.get_operation(3448858738752);`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/operations/3448858738752''`
    operationId: hafah_endpoints.get_operation
    parameters:
      - in: path
        name: operation-id
        required: true
        schema:
          type: string
        description: |
          An operation-id is a unique operation identifier,
          encodes three key pieces of information into a single number,
          with each piece occupying a specific number of bits:

          ```
          msb.....................lsb
           || block | op_pos | type ||
           ||  32b  |  24b   |  8b  ||
          ```

           * block (block number) - occupies 32 bits.

           * op_pos (position of an operation in block) - occupies 24 bits.

           * type (operation type) - occupies 8 bits.
    responses:
      '200':
        description: |
          Operation parameters

          * Returns `hafah_backend.operation`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.operation'
            example: {
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
              "block": 803,
              "trx_id": null,
              "op_pos": 1,
              "op_type_id": 64,
              "timestamp": "2016-03-24T16:45:39",
              "virtual_op": true,
              "operation_id": "3448858738752",
              "trx_in_block": -1
            }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_operation;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_operation(
    "operation-id" TEXT
)
RETURNS hafah_backend.operation 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  _operation_id BIGINT := "operation-id"::BIGINT;
  _result hafah_backend.operation;
BEGIN
  _result := hafah_backend.get_operation(_operation_id);

  IF _result.block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_operation_id(_operation_id);
  END IF;

  IF _result.block <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  RETURN _result;
END
$$;

RESET ROLE;
