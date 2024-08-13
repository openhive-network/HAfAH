SET ROLE hafah_owner;

/** openapi:paths
/block-number-by-date/{timestamp}:
  get:
    tags:
      - Other
    summary: Search for last created block for given date
    description: |
      Returns last created block number for given date

      SQL example
      * `SELECT * FROM hafah_endpoints.get_block_by_time(''2016-06-24T16:05:00'');`
      
      REST call example
      * `GET ''https://%1$s/hafah/block-number-by-date/2016-06-24T16:05:00''`
    operationId: hafah_endpoints.get_block_by_time
    parameters:
      - in: path
        name: timestamp
        required: true
        schema:
          type: string
          format: date-time
        description: Given date
    responses:
      '200':
        description: |
          Last created block at that time

          * Returns `INT`
        content:
          application/json:
            schema:
              type: integer
            example: 2621429
        description: No blocks created at that time
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_block_by_time;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_block_by_time(
    "timestamp" TIMESTAMP
)
RETURNS INT 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  _num INT;
BEGIN

SELECT bv.num INTO _num
FROM hive.blocks_view bv
WHERE bv.created_at BETWEEN "timestamp" - interval '2 seconds' 
AND "timestamp" ORDER BY bv.created_at LIMIT 1;

IF _num <= hive.app_get_irreversible_block() THEN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
ELSE
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
END IF;

RETURN _num;

END
$$;

RESET ROLE;
