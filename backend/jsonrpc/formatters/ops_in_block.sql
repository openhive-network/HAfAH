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
    WITH result AS (
      SELECT ARRAY(
        /*
         * Operation Object Formatting:
         *   - Legacy style: Remove operation_id from object
         *   - New style: Keep operation_id (set to 0)
         */
        SELECT
          CASE
            WHEN _is_legacy_style
              THEN to_jsonb(ops) - 'operation_id'
            ELSE to_jsonb(ops)
          END
        FROM (
          SELECT
            _block_num    AS "block",
            _value::JSON  AS "op",
            _op_in_trx    AS "op_in_trx",
            _timestamp    AS "timestamp",
            _trx_id       AS "trx_id",
            _trx_in_block AS "trx_in_block",
            _virtual_op   AS "virtual_op",
            0             AS "operation_id"
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
     * Response Wrapper:
     *   - Legacy: Return array directly
     *   - New: Wrap in {ops: array} object
     */
    SELECT
    (
      CASE
        WHEN _is_legacy_style
          THEN to_json(result.a)
        ELSE json_build_object('ops', to_json(result.a))
      END
    )
    FROM result
  );
END
$$;

RESET ROLE;
