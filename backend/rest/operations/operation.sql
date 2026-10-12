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
 *   - hafah_backend.helper_operations_view: hafd.operations with type and body
 *   - hafd.transactions: Transaction hash lookup
 *   - hafd.blocks: Block timestamp
 *
 * NOTES:
 *   - Only operations in irreversible blocks are returned; any other ID
 *     yields a NULL row, which the endpoint reports as a missing operation
 *   - Operation ID is globally unique across all blocks
 *   - Virtual operations have no transaction (trx_hash will be NULL)
 *   - is_virtual flag comes from operation_types, not operations table
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_operation(
    _operation_id BIGINT
)
RETURNS hafah_backend.operation
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN (
      -- Operation body: JSON structure with operation type and data
      ov.body,
      ov.block_num,
      -- Binary-to-hex: Transaction hash (32 bytes) as hex string
      -- NULL for virtual operations (they have no transaction)
      encode(ht.trx_hash, 'hex'),
      -- Position of this operation within its transaction
      ov.op_pos::INT,
      ov.op_type_id,
      hb.created_at,
      -- Virtual ops are blockchain-generated (rewards, vesting, interest)
      ov.virtual_op,
      -- Operation ID as TEXT for JSON safety (BigInt > 2^53)
      ov.id::TEXT,
      ov.trx_in_block
    )::hafah_backend.operation
    FROM hafah_backend.helper_operations_view ov
    JOIN hafd.blocks hb ON hb.num = ov.block_num
    -- LEFT JOIN transactions: Virtual ops have no transaction, so LEFT JOIN
    -- Match by block_num + trx_in_block (composite key)
    LEFT JOIN LATERAL (
      -- LIMIT 1: a position holds one transaction (its index is not declared unique)
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ov.block_num AND tx.trx_in_block = ov.trx_in_block
      LIMIT 1
    ) ht ON TRUE
    WHERE ov.id = _operation_id
      AND hafd.operation_id_to_block_num(_operation_id) <= hive.app_get_irreversible_block();
END
$$;

RESET ROLE;
