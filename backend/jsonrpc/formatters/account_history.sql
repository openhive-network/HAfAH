SET ROLE hafah_owner;

/*
 * account_history.sql: JSON formatter for get_account_history JSON-RPC response.
 *
 * Called by: hafah_endpoints.call_get_account_history() in dispatcher.sql
 *
 * JSON-RPC Method: account_history_api.get_account_history
 *
 * Formats account operation history into the JSON-RPC response format.
 * The response format differs between legacy and new styles:
 *   - Legacy: Returns array directly
 *   - New: Returns object with 'history' key containing array
 */

/*
 * ===================================================================================
 * ah_get_account_history_json
 * ===================================================================================
 * PURPOSE: Format account history data as JSON for JSON-RPC response.
 *
 * DATA FLOW:
 *   1. Retrieve operations via ah_get_account_history()
 *   2. Format each operation into [operation_id, operation_object] pairs
 *   3. Handle legacy vs new style formatting:
 *      - Legacy: operation_id removed from inner object
 *      - New: operation_id set to 0 in inner object (kept for compatibility)
 *   4. Wrap result based on style (array vs {history: array})
 *
 * PARAMETERS:
 *   - _filter_low: Low bits of operation type filter
 *   - _filter_high: High bits of operation type filter
 *   - _account: Account name to query
 *   - _start: Starting operation sequence number
 *   - _limit: Maximum operations to return
 *   - _include_reversible: Include reversible blocks
 *   - _is_legacy_style: Use legacy response format
 *
 * RETURNS: JSON object or array depending on style
 */
CREATE OR REPLACE FUNCTION hafah_backend.ah_get_account_history_json(
    _filter_low         NUMERIC,
    _filter_high        NUMERIC,
    _account            VARCHAR,
    _start              BIGINT,
    _limit              BIGINT,
    _include_reversible BOOLEAN,
    _is_legacy_style    BOOLEAN
)
RETURNS JSON
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN (
    /*
     * RESPONSE STRUCTURE:
     *
     * Legacy (condenser_api.*):
     *   [[seq, {block, op, op_in_trx, timestamp, trx_id, trx_in_block, virtual_op}], ...]
     *
     * New (account_history_api.*):
     *   {
     *     "history": [[seq, {block, op, op_in_trx, timestamp, trx_id, trx_in_block, virtual_op, operation_id}], ...]
     *   }
     *
     * Each entry is a tuple: [operation_sequence_number, operation_object]
     * The sequence number is per-account (not global), assigned incrementally.
     */
    WITH result AS (
      SELECT ARRAY(
        SELECT json_build_array(
          /*
           * OPERATION SEQUENCE NUMBER:
           *   Per-account operation index (not global operation ID).
           *   Used for pagination: start parameter references this value.
           */
          ops.operation_id,
          /*
           * OPERATION OBJECT FORMATTING (Legacy vs New Style):
           *
           * Legacy (condenser_api.*):
           *   - Remove operation_id field from inner object
           *   - Pattern: to_jsonb(record) - 'field_name' removes the field
           *   - WHY: Old API didn't include operation_id in the inner object
           *
           * New (account_history_api.*):
           *   - Keep operation_id but set to 0 (placeholder value)
           *   - Pattern: jsonb_set(obj, path[], value, create_missing=false)
           *   - WHY: Operation ID in inner object is deprecated, but kept for
           *          backwards compatibility; actual value is in the tuple
           */
          (
            CASE
              WHEN _is_legacy_style
                THEN to_jsonb(ops) - 'operation_id'  -- JSONB key removal pattern
              ELSE jsonb_set(to_jsonb(ops), ARRAY['operation_id']::TEXT[], '0'::JSONB, FALSE)
            END
          )
        )
        FROM (
          SELECT
            _block        AS "block",         -- Block number containing this operation
            _value        AS "op",            -- Operation body (already JSONB)
            _op_in_trx    AS "op_in_trx",     -- Operation index within transaction
            _timestamp    AS "timestamp",     -- ISO 8601 block timestamp
            _trx_id       AS "trx_id",        -- 40-char hex transaction hash
            _trx_in_block AS "trx_in_block",  -- Transaction index in block
            _virtual_op   AS "virtual_op",    -- TRUE if system-generated
            _operation_id AS "operation_id"   -- Per-account sequence number
          FROM hafah_backend.ah_get_account_history(
            /*
             * TWO'S COMPLEMENT OVERFLOW HANDLING:
             *   JSON numbers are NUMERIC type which can exceed BIGINT range.
             *   numeric_to_bigint() handles unsigned 64-bit values that would
             *   overflow signed BIGINT using two's complement conversion.
             *
             *   Example: Filter value 18446744073709551615 (0xFFFFFFFFFFFFFFFF)
             *   would overflow BIGINT, but represents "all bits set" (all types).
             */
            hafah_backend.numeric_to_bigint(_filter_low),
            hafah_backend.numeric_to_bigint(_filter_high),
            _account,
            _start,
            _limit,
            _include_reversible,
            _is_legacy_style
          )
        ) ops
      ) AS a
    )
    /*
     * RESPONSE WRAPPER (Legacy vs New Style):
     *
     * Legacy (condenser_api.get_account_history):
     *   Returns: [[seq, op], [seq, op], ...]
     *   Direct array, no wrapper object.
     *
     * New (account_history_api.get_account_history):
     *   Returns: {"history": [[seq, op], [seq, op], ...]}
     *   Wrapped in object with 'history' key.
     *
     * WHY json_build_object: Creates {"history": ...} wrapper in one step.
     * to_json(array) converts PostgreSQL array to JSON array.
     */
    SELECT
    (
      CASE
        WHEN _is_legacy_style
          THEN to_json(result.a)  -- Direct array output
        ELSE json_build_object('history', to_json(result.a))  -- Wrapped in object
      END
    )
    FROM result
  );
END
$$;

RESET ROLE;
