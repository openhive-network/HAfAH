/*
 * get_head_block_num: REST endpoint for current head block number.
 *
 * ENDPOINT: GET /headblock
 *
 * PURPOSE: Returns the last irreversible block number in the HAF database.
 *          HAfAH serves irreversible data only, so this is the newest block
 *          whose data the API returns. Useful for clients to determine sync
 *          status and data freshness.
 *
 * RETURNS: Integer block number (e.g., 5000000), NULL when no block is irreversible yet
 *
 * CACHING: 2 second cache (value changes frequently as blockchain advances)
 *
 * DATA SOURCE: hive.app_get_irreversible_block() (hafd.hive_state.consistent_block)
 */
SET ROLE hafah_owner;

/** openapi:paths
/headblock:
  get:
    tags:
      - Other
    summary: Get last irreversible block in the HAF database.
    description: |
      Get the last irreversible block in the HAF database. HAfAH serves
      irreversible data only, so this is the newest block whose data the API
      returns.

      SQL example
      * `SELECT * FROM hafah_endpoints.get_head_block_num();`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/headblock''`
    operationId: hafah_endpoints.get_head_block_num
    responses:
      '200':
        description: |
          Last irreversible block in HAF
          
          * Returns `INT`
        content:
          application/json:
            schema:
              type: integer
            example: 5000000
      '404':
        description: No blocks in the database
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_head_block_num;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_head_block_num()
RETURNS INT 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  -- 0 means no block is irreversible yet: report it as missing, like an empty database
  RETURN NULLIF(hive.app_get_irreversible_block(), 0);
END
$$;

RESET ROLE;
