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
    WITH result AS (
      SELECT ARRAY(
        SELECT json_build_array(
          ops.operation_id,
          /*
           * Operation Object Formatting:
           *   - Legacy style: Remove operation_id from inner object
           *   - New style: Set operation_id to 0 (kept for API compatibility)
           */
          (
            CASE
              WHEN _is_legacy_style
                THEN to_jsonb(ops) - 'operation_id'
              ELSE jsonb_set(to_jsonb(ops), ARRAY['operation_id']::TEXT[], '0'::JSONB, FALSE)
            END
          )
        )
        FROM (
          SELECT
            _block        AS "block",
            _value::JSON  AS "op",
            _op_in_trx    AS "op_in_trx",
            _timestamp    AS "timestamp",
            _trx_id       AS "trx_id",
            _trx_in_block AS "trx_in_block",
            _virtual_op   AS "virtual_op",
            _operation_id AS "operation_id"
          FROM hafah_backend.ah_get_account_history(
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
     * Response Wrapper:
     *   - Legacy: Return array directly
     *   - New: Wrap in {history: array} object
     */
    SELECT
    (
      CASE
        WHEN _is_legacy_style
          THEN to_json(result.a)
        ELSE json_build_object('history', to_json(result.a))
      END
    )
    FROM result
  );
END
$$;

RESET ROLE;
