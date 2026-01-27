/*
 * get_head_block_num: REST endpoint for current head block number.
 *
 * ENDPOINT: GET /headblock
 *
 * PURPOSE: Returns the most recent block number synced to the HAF database.
 *          Useful for clients to determine sync status and data freshness.
 *
 * RETURNS: Integer block number (e.g., 5000000)
 *
 * CACHING: 2 second cache (value changes frequently as blockchain advances)
 *
 * DATA SOURCE: hive.blocks_view (HAF base table)
 */
SET ROLE hafah_owner;

/** openapi:paths
/headblock:
  get:
    tags:
      - Other
    summary: Get last synced block in the HAF database.
    description: |
      Get last synced block in the HAF database

      SQL example
      * `SELECT * FROM hafah_endpoints.get_head_block_num();`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/headblock''`
    operationId: hafah_endpoints.get_head_block_num
    responses:
      '200':
        description: |
          Last block stored in HAF
          
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
  RETURN bv.num FROM hive.blocks_view bv ORDER BY bv.num DESC LIMIT 1;
END
$$;

RESET ROLE;
