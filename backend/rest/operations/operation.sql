SET ROLE hafah_owner;

/*
 * operation.sql: REST API backend for single operation retrieval.
 *
 * Called by: hafah_endpoints.get_operation() in endpoints/operations/get_operation.sql
 *
 * REST Endpoint: GET /operations/{operation-id}
 */

/*
 * ===================================================================================
 * get_operation
 * ===================================================================================
 * PURPOSE: Retrieve a single operation by its ID.
 *
 * PARAMETERS:
 *   _operation_id - Unique operation identifier
 *
 * RETURNS: Operation data including body, block, transaction, and metadata
 *
 * DATA SOURCES:
 *   - hive.operations_view_extended: Operation bodies with decoded JSON
 *   - hafd.operation_types: Operation type metadata including is_virtual flag
 *   - hive.transactions_view: Transaction hash lookup
 *
 * NOTES:
 *   - Operation ID is globally unique across all blocks
 *   - Virtual operations have no transaction (trx_hash will be NULL)
 *   - is_virtual flag comes from operation_types, not operations table
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_operation(
    _operation_id BIGINT
)
RETURNS hafah_backend.operation
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS
$$
BEGIN
  RETURN (
      -- Operation body: JSON structure with operation type and data
      ov.body,
      ov.block_num,
      -- Binary-to-hex: Transaction hash (32 bytes) as hex string
      -- NULL for virtual operations (they have no transaction)
      encode(htv.trx_hash, 'hex'),
      -- Position of this operation within its transaction
      ov.op_pos,
      ov.op_type_id,
      ov.timestamp,
      -- Virtual flag: Comes from operation_types, not operations table
      -- Virtual ops are blockchain-generated (rewards, vesting, interest)
      hot.is_virtual,
      -- Operation ID as TEXT for JSON safety (BigInt > 2^53)
      ov.id::TEXT,
      ov.trx_in_block
    )::hafah_backend.operation
    FROM hive.operations_view_extended ov
    -- JOIN operation_types: Required to get is_virtual flag
    -- This metadata is normalized out of the operations table
    JOIN hafd.operation_types hot ON hot.id = ov.op_type_id
    -- LEFT JOIN transactions: Virtual ops have no transaction, so LEFT JOIN
    -- Match by block_num + trx_in_block (composite key)
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ov.block_num AND htv.trx_in_block = ov.trx_in_block
    WHERE ov.id = _operation_id
      AND ov.id >= hafd.operation_id(hafd.operation_id_to_block_num(_operation_id), 0)
      AND ov.id < hafd.operation_id(hafd.operation_id_to_block_num(_operation_id) + 1, 0);
END
$$;

RESET ROLE;
