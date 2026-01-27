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
 * Result type for get_transaction function
 */
DROP TYPE IF EXISTS hafah_backend.get_transaction_result CASCADE;
CREATE TYPE hafah_backend.get_transaction_result AS (
    _ref_block_num   INT,
    _ref_block_prefix BIGINT,
    _expiration      TEXT,
    _block_num       INT,
    _trx_in_block    SMALLINT,
    _signature       TEXT,
    _multisig_number SMALLINT
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
  __result         hive.transactions_view%ROWTYPE;
  __multisig_number SMALLINT;
BEGIN
  SELECT * INTO __result
  FROM hive.transactions_view ht
  WHERE ht.trx_hash = _trx_hash;

  /*
   * Reversibility Check:
   *   If not including reversible and transaction is in reversible block,
   *   return empty result
   */
  IF NOT _include_reversible AND __result.block_num > hive.app_get_irreversible_block() THEN
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
   * Count multisig signatures for this transaction
   */
  SELECT count(*) INTO __multisig_number
  FROM hive.transactions_multisig_view htm
  WHERE htm.trx_hash = _trx_hash;

  RETURN QUERY
    SELECT
      __result.ref_block_num                            AS _ref_block_num,
      __result.ref_block_prefix                         AS _ref_block_prefix,
      trim(both '"' from to_json(__result.expiration)::TEXT) AS _expiration,
      __result.block_num                                AS _block_num,
      __result.trx_in_block                             AS _trx_in_block,
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
    _value TEXT
)
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN QUERY
    SELECT
      (
        CASE
          WHEN _is_legacy_style
            THEN hive.get_legacy_style_operation(ho.body_binary)::TEXT
          ELSE ho.body::TEXT
        END
      ) AS _value
    FROM hive.operations_view ho
    JOIN hafd.operation_types hot ON ho.op_type_id = hot.id
    WHERE ho.block_num = _block_num
      AND ho.trx_in_block = _trx_in_block
      AND (_include_virtual OR hot.is_virtual = FALSE)
    ORDER BY ho.id;
END
$$;

RESET ROLE;
