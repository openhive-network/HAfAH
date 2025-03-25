SET ROLE hafah_owner;


/** openapi:components:schemas
hafah_backend.version_type:
  type: object
  properties:
    app_name:
      type: string
      description: Application name
    commit:
      type: string
      description: Last commit hash
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.version_type CASCADE;
CREATE TYPE hafah_backend.version_type AS (
    "app_name" TEXT,
    "commit" TEXT
);
-- openapi-generated-code-end

/** openapi:paths
/version:
  get:
    tags:
      - Other
    summary: hafah''s version
    description: |
      Get hafah''s last commit hash (hash is used for versioning).

      SQL example
      * `SELECT * FROM hafah_endpoints.get_version();`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/version''`
    operationId: hafah_endpoints.get_version
    responses:
      '200':
        description: |

          * Returns `hafah_backend.version_type`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.version_type'
            example: c2fed8958584511ef1a66dab3dbac8c40f3518f0
      '404':
        description: App not installed
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_version;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_version()
RETURNS hafah_backend.version_type 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN (
    'PostgRESTHAfAH', 
    (SELECT * FROM hafah_python.get_version())
  )::hafah_backend.version_type;
END;
$$
;

RESET ROLE;
