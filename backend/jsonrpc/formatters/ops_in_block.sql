SET ROLE hafah_owner;

/*
 * ops_in_block.sql: JSON formatter for get_ops_in_block JSON-RPC response.
 *
 * Called by: hafah_endpoints.call_get_ops_in_block() in dispatcher.sql
 *
 * JSON-RPC Method: account_history_api.get_ops_in_block
 *
 * Formats block operations into the JSON-RPC response format.
 * The response format differs between legacy and new styles:
 *   - Legacy: Returns array directly
 *   - New: Returns object with 'ops' key containing array
 */

/*
 * ===================================================================================
 * get_ops_in_block_json
 * ===================================================================================
 * PURPOSE: Format block operations as JSON for JSON-RPC response.
 *
 * DATA FLOW:
 *   1. Set cache headers based on block reversibility
 *   2. Retrieve operations via get_ops_in_block()
 *   3. Format each operation with metadata
 *   4. Handle legacy vs new style formatting:
 *      - Legacy: operation_id removed from object
 *      - New: operation_id kept (set to 0)
 *   5. Wrap result based on style (array vs {ops: array})
 *
 * PARAMETERS:
 *   - _block_num: Block number to query
 *   - _only_virtual: Filter to virtual operations only
 *   - _include_reversible: Include reversible blocks
 *   - _is_legacy_style: Use legacy response format
 *
 * RETURNS: JSON object or array depending on style
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_block_json(
    _block_num          INT,
    _only_virtual       BOOLEAN,
    _include_reversible BOOLEAN,
    _is_legacy_style    BOOLEAN
)
RETURNS JSON
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  /*
   * Cache Control:
   *   - Irreversible blocks: cache for 1 year (immutable)
   *   - Reversible blocks: cache for 3 seconds (may change)
   */
  IF _block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  RETURN (
    /*
     * RESPONSE STRUCTURE:
     *
     * Legacy (condenser_api.get_ops_in_block):
     *   [{block, op, op_in_trx, timestamp, trx_id, trx_in_block, virtual_op}, ...]
     *
     * New (account_history_api.get_ops_in_block):
     *   {
     *     "ops": [{block, op, op_in_trx, timestamp, trx_id, trx_in_block, virtual_op, operation_id}, ...]
     *   }
     *
     * Unlike get_account_history, these are not [seq, op] tuples but flat objects.
     */
    WITH result AS (
      SELECT ARRAY(
        /*
         * OPERATION OBJECT FORMATTING (Legacy vs New Style):
         *
         * Legacy (condenser_api.*):
         *   - Remove operation_id field entirely
         *   - Pattern: to_jsonb(record) - 'field_name'
         *   - PostgreSQL JSONB supports key deletion with minus operator
         *
         * New (account_history_api.*):
         *   - Include operation_id (set to 0 as placeholder)
         *   - WHY 0: This endpoint doesn't track per-account sequence numbers,
         *            but includes field for structural consistency with other endpoints
         */
        SELECT
          CASE
            WHEN _is_legacy_style
              THEN to_jsonb(ops) - 'operation_id'  -- JSONB key removal
            ELSE to_jsonb(ops)  -- Keep all fields including operation_id
          END
        FROM (
          SELECT
            _block_num    AS "block",         -- Block number (same for all ops in result)
            _value::JSON  AS "op",            -- Operation body (formatted per style)
            _op_in_trx    AS "op_in_trx",     -- Operation index within transaction
            _timestamp    AS "timestamp",     -- ISO 8601 block timestamp
            _trx_id       AS "trx_id",        -- 40-char hex (or 40 zeros for virtual ops)
            _trx_in_block AS "trx_in_block",  -- Transaction index (or max uint32 for virtual)
            _virtual_op   AS "virtual_op",    -- TRUE if system-generated operation
            0             AS "operation_id"   -- Placeholder (not per-account sequence)
          FROM hafah_backend.get_ops_in_block(
            _block_num,
            _only_virtual,
            _include_reversible,
            _is_legacy_style
          )
        ) ops
      ) AS a
    )
    /*
     * RESPONSE WRAPPER (Legacy vs New Style):
     *
     * Legacy (condenser_api.get_ops_in_block):
     *   Returns: [{op}, {op}, ...]
     *   Direct array of operation objects.
     *
     * New (account_history_api.get_ops_in_block):
     *   Returns: {"ops": [{op}, {op}, ...]}
     *   Wrapped in object with 'ops' key.
     *
     * JSON BUILDING PATTERNS:
     *   - to_json(array): Converts PostgreSQL array to JSON array
     *   - json_build_object('key', value): Creates {"key": value} object
     */
    SELECT
    (
      CASE
        WHEN _is_legacy_style
          THEN to_json(result.a)  -- Direct array output
        ELSE json_build_object('ops', to_json(result.a))  -- Wrapped in {ops: [...]}
      END
    )
    FROM result
  );
END
$$;

RESET ROLE;
