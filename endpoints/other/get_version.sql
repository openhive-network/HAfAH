/*
 * get_version: REST endpoint for API version information.
 *
 * ENDPOINT: GET /version
 *
 * PURPOSE: Returns HAfAH version info including app name and git commit hash.
 *          Used for version identification and deployment verification.
 *
 * RETURNS:
 *   - app_name: "PostgRESTHAfAH"
 *   - commit: Git commit hash from hafah_backend.version table
 *
 * CACHING: 2 second cache (always short since version may change on redeploy)
 *
 * NOTE: Also defines hafah_backend.version_type composite type used for the response.
 */
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
            example: {
                "app_name": "PostgRESTHAfAH",
                "commit": "136fe35c62cdc0fd7d6ff41cf6c946cadc2a4cd5"
              }
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
    (SELECT git_hash FROM hafah_backend.version LIMIT 1)
  )::hafah_backend.version_type;
END;
$$
;

RESET ROLE;
