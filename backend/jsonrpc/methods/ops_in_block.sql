SET ROLE hafah_owner;

/*
 * ops_in_block.sql: get_ops_in_block JSON-RPC method implementation.
 *
 * Called by: hafah_endpoints.call_get_ops_in_block() in dispatcher.sql
 *            hafah_backend.get_ops_in_block_json() in formatters/ops_in_block.sql
 *
 * JSON-RPC Method: account_history_api.get_ops_in_block
 *
 * Returns operations from a specific block with optional filtering for virtual ops.
 *
 * VIRTUAL VS REAL OPERATIONS:
 *   Real operations: User-initiated (vote, transfer, comment, etc.)
 *   Virtual operations: System-generated (curation_reward, author_reward, etc.)
 *
 *   Virtual ops have:
 *   - trx_in_block = -1 (no transaction)
 *   - trx_id = 40 zeros (placeholder)
 *   - is_virtual = TRUE in operation_types
 *
 *   This endpoint supports:
 *   - _only_virtual = FALSE: Return all operations (default)
 *   - _only_virtual = TRUE: Return only virtual operations
 */

/*
 * ===================================================================================
 * get_ops_in_block
 * ===================================================================================
 * PURPOSE: Retrieve operations from a specific block for JSON-RPC API.
 *
 * DATA FLOW:
 *   1. Check if block is within reversible range (if _include_reversible = FALSE)
 *   2. Query operations from helper_operations_view for the block
 *   3. Join with blocks_view for timestamp
 *   4. Join with transactions_view for transaction hash
 *   5. Format and return results ordered by operation ID
 *
 * PARAMETERS:
 *   - _block_num: Block number to query
 *   - _only_virtual: If TRUE, return only virtual operations
 *   - _include_reversible: If TRUE, include operations from reversible blocks
 *   - _is_legacy_style: If TRUE, format operations in legacy style
 *
 * RETURNS: Table of operations with transaction context
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_block(
    _block_num          INT,
    _only_virtual       BOOLEAN,
    _include_reversible BOOLEAN,
    _is_legacy_style    BOOLEAN
)
RETURNS TABLE(
    _trx_id       TEXT,
    _trx_in_block BIGINT,
    _op_in_trx    BIGINT,
    _virtual_op   BOOLEAN,
    _timestamp    TEXT,
    _value        TEXT,
    _operation_id BIGINT
)
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS $$
BEGIN
  /*
   * Reversibility Check:
   *   If not including reversible blocks and block is beyond irreversible,
   *   return empty result set
   */
  IF (NOT _include_reversible) AND _block_num > hive.app_get_irreversible_block() THEN
    RETURN QUERY SELECT
      NULL::TEXT,    -- _trx_id
      NULL::BIGINT,  -- _trx_in_block
      NULL::BIGINT,  -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT,    -- _timestamp
      NULL::TEXT,    -- _value
      NULL::BIGINT   -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT
      /*
       * TRANSACTION ID HANDLING:
       *   - Real operations: 40-char hex hash from transactions_view
       *   - Virtual operations: trx_hash IS NULL → return 40 zeros
       *
       * WHY LEFT JOIN: Virtual ops won't match any transaction, giving NULL.
       */
      (
        CASE
          WHEN ht.trx_hash IS NULL
            THEN '0000000000000000000000000000000000000000'  -- WHY: Consistent 40-char placeholder
          ELSE encode(ht.trx_hash, 'hex')
        END
      ) AS _trx_id,
      /*
       * TRANSACTION INDEX:
       *   - Real operations: 0-based index in block
       *   - Virtual operations: 4294967295 (max uint32)
       *
       * WHY max uint32: Signals "no transaction" to clients, matches Hive node behavior.
       */
      (
        CASE
          WHEN ht.trx_in_block IS NULL
            THEN 4294967295
          ELSE ht.trx_in_block
        END
      ) AS _trx_in_block,
      T.op_pos AS _op_in_trx,         -- Operation position within transaction
      T.virtual_op AS _virtual_op,    -- TRUE if system-generated operation
      -- WHY trim: Remove quotes added by to_json for clean ISO 8601 timestamp
      trim(both '"' from to_json(hb.created_at)::TEXT) AS _timestamp,
      /*
       * OPERATION BODY FORMAT:
       *   Legacy: {"vote": {...}} - Type as key
       *   New: {"type": "vote_operation", "value": {...}} - Explicit type field
       */
      (
        CASE
          WHEN _is_legacy_style
            THEN hive.get_legacy_style_operation(T.body_binary)::TEXT
          ELSE T.body::TEXT
        END
      ) AS _value,
      T.id::BIGINT AS _operation_id
    FROM (
      /*
       * HELPER VIEW USAGE:
       *   helper_operations_view pre-joins with operation_types to include virtual_op flag.
       *   More efficient than joining in outer query for every row.
       */
      SELECT
        ho.id,
        ho.block_num,
        ho.trx_in_block,
        ho.op_pos,
        ho.body,
        ho.body_binary,
        ho.op_type_id,
        ho.virtual_op
      FROM hafah_backend.helper_operations_view ho
      WHERE ho.block_num = _block_num
        /*
         * VIRTUAL OPERATION FILTER:
         *   - _only_virtual = FALSE: Return all operations (real + virtual)
         *   - _only_virtual = TRUE: Return only virtual operations
         */
        AND (_only_virtual = FALSE OR ho.virtual_op = TRUE)
    ) T
    JOIN hive.blocks_view hb ON hb.num = T.block_num  -- WHY: Get block timestamp
    /*
     * LEFT JOIN TRANSACTIONS:
     *   Virtual operations have no transaction, so LEFT JOIN ensures they're included.
     *   The CASE statements above handle NULL trx_hash appropriately.
     */
    LEFT JOIN hive.transactions_view ht
      ON T.block_num = ht.block_num
      AND T.trx_in_block = ht.trx_in_block
    ORDER BY _operation_id;  -- WHY: Maintain operation order within block
END
$$;

RESET ROLE;
