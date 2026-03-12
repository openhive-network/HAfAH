SET ROLE hafah_owner;

/*
 * transaction.sql: get_transaction JSON-RPC method implementation.
 *
 * Called by: hafah_backend.get_transaction_json() in formatters/transaction.sql
 *
 * JSON-RPC Method: account_history_api.get_transaction
 *
 * Contains the core transaction retrieval functions:
 *   - get_transaction: Main transaction lookup
 *   - get_multi_signatures_in_transaction: Multisig signature retrieval
 *   - get_ops_in_transaction: Operations within a transaction
 */

/*
 * RESULT TYPE: get_transaction_result
 *
 * Fields match Hive transaction structure:
 *   - ref_block_num: Block number referenced in TaPoS (Transaction as Proof of Stake)
 *   - ref_block_prefix: Block ID prefix for TaPoS validation
 *   - expiration: Transaction expiration timestamp
 *   - block_num: Block where transaction was included
 *   - trx_in_block: Transaction index within the block
 *   - signature: Primary transaction signature (hex-encoded)
 *   - multisig_number: Count of additional signatures (for multisig transactions)
 */
DROP TYPE IF EXISTS hafah_backend.get_transaction_result CASCADE;
CREATE TYPE hafah_backend.get_transaction_result AS (
    _ref_block_num   INT,       -- TaPoS reference block number
    _ref_block_prefix BIGINT,   -- TaPoS reference block prefix
    _expiration      TEXT,      -- ISO 8601 expiration time
    _block_num       INT,       -- Block containing this transaction
    _trx_in_block    SMALLINT,  -- Index in block (0-based)
    _signature       TEXT,      -- Primary signature (hex)
    _multisig_number SMALLINT   -- Additional signature count
);

/*
 * ===================================================================================
 * get_transaction
 * ===================================================================================
 * PURPOSE: Retrieve transaction details by hash.
 *
 * DATA FLOW:
 *   1. Look up transaction by hash in transactions_view
 *   2. Check reversibility constraints
 *   3. Count multisig signatures
 *   4. Return transaction metadata
 *
 * PARAMETERS:
 *   - _trx_hash: Transaction hash (20 bytes)
 *   - _include_reversible: Include reversible blocks
 *
 * RETURNS: Transaction metadata including ref_block info, expiration, signature
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_transaction(
    _trx_hash           BYTEA,
    _include_reversible BOOLEAN
)
RETURNS SETOF hafah_backend.get_transaction_result
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __result         hive.transactions_view%ROWTYPE;  -- Full transaction row
  __multisig_number SMALLINT;                        -- Additional signature count
BEGIN
  /*
   * TRANSACTION LOOKUP:
   *   Find transaction by its 20-byte hash (160 bits).
   *   Returns full row including TaPoS fields, expiration, and signature.
   */
  SELECT * INTO __result
  FROM hive.transactions_view ht
  WHERE ht.trx_hash = _trx_hash;

  /*
   * REVERSIBILITY CHECK:
   *   Transactions in reversible blocks may disappear during chain reorganization.
   *   If caller requests only irreversible data, filter out reversible transactions.
   *
   * WHY: Exchanges and other services need confirmed transactions only.
   *      app_get_irreversible_block() returns last finalized block number.
   */
  IF NOT _include_reversible AND __result.block_num > hive.app_get_irreversible_block() THEN
    -- WHY: Return empty set (not NULL row) for consistent API behavior
    RETURN QUERY SELECT
      NULL::INT,
      NULL::BIGINT,
      NULL::TEXT,
      NULL::INT,
      NULL::SMALLINT,
      NULL::TEXT,
      NULL::SMALLINT
    LIMIT 0;
    RETURN;
  END IF;

  /*
   * MULTISIG SIGNATURE COUNT:
   *   Hive supports multi-signature transactions. The primary signature is in
   *   transactions_view. Additional signatures are in transactions_multisig_view.
   *
   * WHY: Caller needs this count to know if there are additional signatures
   *      to fetch via get_multi_signatures_in_transaction().
   */
  SELECT count(*) INTO __multisig_number
  FROM hive.transactions_multisig_view htm
  WHERE htm.trx_hash = _trx_hash;

  RETURN QUERY
    SELECT
      __result.ref_block_num                            AS _ref_block_num,
      __result.ref_block_prefix                         AS _ref_block_prefix,
      -- WHY trim: to_json adds quotes around timestamp, we need raw string
      trim(both '"' from to_json(__result.expiration)::TEXT) AS _expiration,
      __result.block_num                                AS _block_num,
      __result.trx_in_block                             AS _trx_in_block,
      -- WHY encode: Convert binary signature to hex string for JSON
      encode(__result.signature, 'hex')                 AS _signature,
      __multisig_number;
END
$$;

/*
 * ===================================================================================
 * get_multi_signatures_in_transaction
 * ===================================================================================
 * PURPOSE: Retrieve additional signatures for multisig transactions.
 *
 * PARAMETERS:
 *   - _trx_hash: Transaction hash
 *
 * RETURNS: Table of hex-encoded signatures
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_multi_signatures_in_transaction(
    _trx_hash BYTEA
)
RETURNS TABLE(
    _signature TEXT
)
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN QUERY
    SELECT encode(htm.signature, 'hex') AS _signature
    FROM hive.transactions_multisig_view htm
    WHERE htm.trx_hash = _trx_hash;
END
$$;

/*
 * ===================================================================================
 * get_ops_in_transaction
 * ===================================================================================
 * PURPOSE: Retrieve operations within a specific transaction.
 *
 * DATA FLOW:
 *   1. Query operations_view for the specific block/transaction
 *   2. Filter virtual ops based on _include_virtual
 *   3. Format operation body based on style
 *   4. Return ordered by operation ID
 *
 * PARAMETERS:
 *   - _block_num: Block containing the transaction
 *   - _trx_in_block: Transaction index within block
 *   - _is_legacy_style: Format operations in legacy style
 *   - _include_virtual: Include virtual operations (default FALSE)
 *
 * RETURNS: Table of operation bodies as text
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_transaction(
    _block_num       INT,
    _trx_in_block    INT,
    _is_legacy_style BOOLEAN,
    _include_virtual BOOLEAN = FALSE
)
RETURNS TABLE(
    _value JSONB
)
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN QUERY
    SELECT
      /*
       * OPERATION BODY FORMATTING:
       *   - Legacy style: {"vote": {"voter": "alice", ...}}
       *   - New style: {"type": "vote_operation", "value": {"voter": "alice", ...}}
       *
       * WHY: Legacy style for backwards compatibility with older clients.
       *      get_legacy_style_operation() converts from binary representation.
       */
      (
        CASE
          WHEN _is_legacy_style
            THEN hive.get_legacy_style_operation(ho.body_value)::TEXT
          ELSE ho.body::TEXT  -- WHY: body column already in new JSON format
        END
      ) AS _value
    FROM hive.operations_view ho
    JOIN hafd.operation_types hot ON ho.op_type_id = hot.id
    WHERE ho.block_num = _block_num
      AND ho.trx_in_block = _trx_in_block
      /*
       * VIRTUAL OPERATION FILTERING:
       *   Virtual ops are generated by the blockchain (rewards, etc.), not user transactions.
       *   They have the same block/trx context but are separate from actual transaction ops.
       *
       *   - _include_virtual = TRUE: Include all operations
       *   - _include_virtual = FALSE: Only real transaction operations
       */
      AND (_include_virtual OR hot.is_virtual = FALSE)
    ORDER BY ho.id;  -- WHY: Maintain operation order within transaction
END
$$;

RESET ROLE;
