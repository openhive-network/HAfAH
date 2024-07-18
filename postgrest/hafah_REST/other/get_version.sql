SET ROLE hafah_owner;

/** openapi:paths
/version:
  get:
    tags:
      - Other
    summary: hafah's version
    description: |
      Get hafah's last commit hash that determinates its version

      SQL example
      * `SELECT * FROM hafah_rest.get_version();`
      
      REST call example
      * `GET https://{hafah-host}/hafah-rest/version`
    operationId: hafah_rest.get_version
    responses:
      '200':
        description: |

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSON
            example: 'c2fed8958584511ef1a66dab3dbac8c40f3518f0'
      '404':
        description: App not installed
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_version;
CREATE OR REPLACE FUNCTION hafah_rest.get_version()
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN json_build_object('app_name', 'PostgRESTHAfAH', 'commit', (SELECT * FROM hafah_python.get_version()));
END;
$$
;

RESET ROLE;
