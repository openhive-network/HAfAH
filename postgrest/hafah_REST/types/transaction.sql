SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.transaction:
  type: object
  properties:
    transaction_json:
      $ref: '#/components/schemas/hafah_backend.transactions'
      x-sql-datatype: JSONB
      description: transactions in the block
    transaction_id:
      type: string
      description: hash of the transaction
    block_num:
      type: integer
      description: block number
    transaction_num:
      type: integer
      description: transaction identifier that indicates its sequence number in block
    timestamp:
      type: string
      format: date-time
      description: the timestamp when the block was created

 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.transaction CASCADE;
CREATE TYPE hafah_backend.transaction AS (
    "transaction_json" JSONB,
    "transaction_id" TEXT,
    "block_num" INT,
    "transaction_num" INT,
    "timestamp" TIMESTAMP
);
-- openapi-generated-code-end

RESET ROLE;
