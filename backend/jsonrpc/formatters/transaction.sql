SET ROLE hafah_owner;

/*
 * transaction.sql: JSON formatter for get_transaction JSON-RPC response.
 *
 * Called by: hafah_endpoints.call_get_transaction() in dispatcher.sql
 *
 * JSON-RPC Method: account_history_api.get_transaction
 *
 * Formats raw transaction data into the JSON-RPC response format, including:
 *   - Transaction metadata (ref_block_num, ref_block_prefix, expiration)
 *   - Operations array (via get_ops_in_transaction)
 *   - Signatures (single or multisig)
 *   - Transaction identification (transaction_id, block_num, transaction_num)
 */

/*
 * ===================================================================================
 * get_transaction_json
 * ===================================================================================
 * PURPOSE: Format transaction data as JSON for JSON-RPC response.
 *
 * DATA FLOW:
 *   1. Retrieve raw transaction data via get_transaction()
 *   2. Validate transaction exists (raise exception if not found)
 *   3. Set cache headers based on reversibility
 *   4. Format operations array via get_ops_in_transaction()
 *   5. Handle signatures (single, none, or multisig)
 *   6. Return complete JSON object
 *
 * PARAMETERS:
 *   - _trx_hash: Transaction hash (20 bytes)
 *   - _include_reversible: Include reversible blocks in results
 *   - _is_legacy_style: Use legacy operation format
 *   - _include_virtual: Include virtual operations (default FALSE)
 *
 * RETURNS: JSON object with full transaction details
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_transaction_json(
    _trx_hash           BYTEA,
    _include_reversible BOOLEAN,
    _is_legacy_style    BOOLEAN,
    _include_virtual    BOOLEAN = FALSE
)
RETURNS JSON
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __pre_result hafah_backend.get_transaction_result;
BEGIN
  SELECT * INTO __pre_result
  FROM hafah_backend.get_transaction(_trx_hash, _include_reversible);

  IF NOT FOUND OR __pre_result._block_num IS NULL THEN
    RAISE EXCEPTION 'Assert Exception:false: Unknown Transaction %',
      RPAD(encode(_trx_hash, 'hex'), 40, '0');
  END IF;

  /*
   * Cache Control:
   *   - Irreversible blocks: cache for 1 year (immutable)
   *   - Reversible blocks: cache for 3 seconds (may change)
   */
  IF __pre_result._block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  RETURN (
    /*
     * JSON RESPONSE STRUCTURE:
     *   {
     *     "ref_block_num": INT,      -- TaPoS reference block
     *     "ref_block_prefix": BIGINT, -- TaPoS block ID prefix
     *     "extensions": [],          -- Protocol extensions (always empty for now)
     *     "expiration": "YYYY-MM-DDTHH:MM:SS", -- ISO 8601 timestamp
     *     "operations": [...],       -- Array of operations in this transaction
     *     "signatures": [...],       -- Array of hex-encoded signatures
     *     "transaction_id": "...",   -- 40-char hex hash
     *     "block_num": INT,          -- Block containing this transaction
     *     "transaction_num": INT     -- Index within block (0-based)
     *   }
     */
    SELECT to_json(a)
    FROM (
      SELECT
        __pre_result._ref_block_num    AS "ref_block_num",
        __pre_result._ref_block_prefix AS "ref_block_prefix",
        /*
         * EXTENSIONS FIELD:
         *   Protocol extensions array - currently always empty.
         *   Reserved for future protocol changes.
         */
        ARRAY[]::INT[]                 AS "extensions",
        /*
         * TIMESTAMP FORMAT:
         *   Already in ISO 8601 format from get_transaction().
         *   Example: "2024-01-15T12:30:45"
         */
        __pre_result._expiration       AS "expiration",
        /*
         * Operations Array:
         * Fetches all operations in this transaction, formatted per style
         */
        (
          SELECT ARRAY(
            SELECT _value::JSON
            FROM hafah_backend.get_ops_in_transaction(
              __pre_result._block_num,
              __pre_result._trx_in_block,
              _is_legacy_style,
              _include_virtual
            )
          )
        ) AS "operations",
        /*
         * SIGNATURES ARRAY:
         *   Hive supports multi-signature transactions for enhanced security.
         *   Signatures are 65-byte (520-bit) binary values encoded as 130-char hex strings.
         *
         *   Cases:
         *   1. Single signature (most common): [primary_signature]
         *   2. No signature (rare, system transactions): []
         *   3. Multisig: [primary, additional_1, additional_2, ...]
         *
         *   WHY array_prepend: Primary signature from transactions_view comes first,
         *   additional signatures from transactions_multisig_view follow.
         */
        (
          CASE
            WHEN __pre_result._multisig_number = 0 AND __pre_result._signature IS NOT NULL
              THEN ARRAY[__pre_result._signature]  -- Common case: single signer
            WHEN __pre_result._multisig_number = 0 AND __pre_result._signature IS NULL
              THEN '{}'  -- Edge case: unsigned system transaction
            ELSE (
              array_prepend(
                __pre_result._signature,
                (
                  SELECT ARRAY(
                    /*
                     * BINARY TO HEX ENCODING:
                     *   encode(signature, 'hex') converts 65-byte binary to 130-char hex.
                     *   JSON cannot represent binary, so hex string is standard encoding.
                     */
                    SELECT encode(signature, 'hex')
                    FROM hive.transactions_multisig_view
                    WHERE trx_hash = _trx_hash
                  )
                )
              )
            )
          END
        ) AS "signatures",
        /*
         * TRANSACTION ID (BINARY TO HEX):
         *   Transaction hash is 20 bytes (160 bits) stored as BYTEA.
         *   encode(..., 'hex') produces 40-character lowercase hex string.
         *
         *   WHY hex: JSON cannot represent binary data. Hex is human-readable
         *   and matches the format used by Hive nodes and block explorers.
         */
        encode(_trx_hash, 'hex')       AS "transaction_id",
        __pre_result._block_num        AS "block_num",
        __pre_result._trx_in_block     AS "transaction_num"
    ) a
  );
END
$$;

RESET ROLE;
