SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_endpoints.operation:
  type: object
  properties:
    op:
      type: string
      x-sql-datatype: JSONB
      description: operation body
    block:
      type: integer
      description: operation block number
    trx_id:
      type: string
      description: hash of the transaction
    op_pos:
      type: integer
      description: >-
        operation identifier that indicates its sequence number in transaction
    timestamp:
      type: string
      format: date-time
      description: creation date
    virtual_op:
      type: boolean
      description: true if is a virtual operation
    operation_id:
      type: string
      description: >-
        unique operation identifier with
        an encoded block number and operation type id
    trx_in_block:
      type: integer
      x-sql-datatype: SMALLINT
      description: >-
        transaction identifier that indicates its sequence number in block
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_endpoints.operation CASCADE;
CREATE TYPE hafah_endpoints.operation AS (
    "op" JSONB,
    "block" INT,
    "trx_id" TEXT,
    "op_pos" INT,
    "timestamp" TIMESTAMP,
    "virtual_op" BOOLEAN,
    "operation_id" TEXT,
    "trx_in_block" SMALLINT
);
-- openapi-generated-code-end

/** openapi:paths
/operations/{operation-id}:
  get:
    tags:
      - Operations
    summary: Get informations about the operation
    description: |
      Get operation''s body and its extended parameters

      SQL example
      * `SELECT * FROM hafah_endpoints.get_operation(3448858738752);`
      
      REST call example
      * `GET ''https://%1$s/hafah/operations/3448858738752''`
    operationId: hafah_endpoints.get_operation
    parameters:
      - in: path
        name: operation-id
        required: true
        schema:
          type: integer
          x-sql-datatype: BIGINT
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

          * Returns `hafah_endpoints.operation`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_endpoints.operation'
            example:
              - op: {
                  "type": "producer_reward_operation",
                  "value": {
                    "producer": "initminer",
                    "vesting_shares": {
                      "nai": "@@000000021",
                      "amount": "1000",
                      "precision": 3
                    }
                  }
                }
                block: 803
                trx_id: null
                op_pos: 1
                timestamp: "2016-03-24T16:45:39"
                virtual_op: true
                operation_id: "3448858738752"
                trx_in_block: -1
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_operation;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_operation(
    "operation-id" BIGINT
)
RETURNS hafah_endpoints.operation 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
 _block_num INT := (SELECT ov.block_num FROM hive.operations_view ov WHERE ov.id = "operation-id");
BEGIN

IF _block_num <= hive.app_get_irreversible_block() THEN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
ELSE
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
END IF;

RETURN (
  SELECT ROW (
      ov.body,
      ov.block_num,
      encode(htv.trx_hash, 'hex'),
      ov.op_pos,
      ov.timestamp,
      hot.is_virtual,
      ov.id::TEXT,
      ov.trx_in_block
  )
    FROM hive.operations_view_extended ov
    JOIN hive.operation_types hot ON hot.id = ov.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ov.block_num AND htv.trx_in_block = ov.trx_in_block
	  WHERE ov.id = "operation-id"
);
END
$$;

RESET ROLE;
