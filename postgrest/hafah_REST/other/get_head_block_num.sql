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
      * `GET ''https://%1$s/hafah/headblock''`
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
AS
$$
BEGIN

  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  RETURN bv.num FROM hive.blocks_view bv ORDER BY bv.num DESC LIMIT 1;

END
$$;

RESET ROLE;
