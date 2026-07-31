/*
 * get_sync_status: REST endpoint for sync status / data freshness.
 *
 * ENDPOINT: GET /sync-status
 *
 * PURPOSE: Returns the last block for which HAfAH data is available, as an
 *          object with both the block number and its timestamp, so monitors
 *          and health checks can judge freshness in one call. This is the
 *          HAF-wide uniform sync-status shape rolled out across app repos.
 *
 *          HAfAH serves account history directly from HAF's own tables and
 *          has no app-specific sync context, so its data freshness is HAF's
 *          freshness: this endpoint reports HAF's consistent (last
 *          irreversible) block, i.e. hafd.hive_state.consistent_block, read
 *          through the public HAF API (hive.app_get_irreversible_block())
 *          per this repo's convention of avoiding internal hafd tables.
 *
 * RETURNS: JSON {"last_block_num": INT, "last_block_time": TEXT|null}
 *
 * CACHING: No cache (max-age=0): used for real-time sync-status / health
 *          monitoring.
 *
 * DATA SOURCE: hive.app_get_irreversible_block(), hive.blocks_view
 */
SET ROLE hafah_owner;

/** openapi:paths
/sync-status:
  get:
    tags:
      - Other
    summary: Get hafah''s sync status
    description: |
      Get the last block for which HAfAH data is available, as an object
      containing both the block number and its timestamp (UTC). This is the
      uniform HAF-app sync/health endpoint: the timestamp lets a consumer
      compute staleness with a single call (`age = now() - last_block_time`)
      without needing a separate head-block reference.

      HAfAH serves account history directly from HAF''s own tables and has no
      app-specific sync process, so its data freshness is HAF''s freshness:
      this endpoint reports HAF''s consistent (last irreversible) block. For
      HAfAH, "synced" means the HAF database itself is synced (its last
      irreversible block is recent).

      SQL example
      * `SELECT * FROM hafah_endpoints.get_sync_status();`

      REST call example
      * `GET ''https://%1$s/hafah-api/sync-status''`
    operationId: hafah_endpoints.get_sync_status
    responses:
      '200':
        description: |
          HAF''s consistent (last irreversible) block and its timestamp.
          `last_block_time` is null if HAF has no consistent block yet.
          While the HAF instance is still in massive sync (indexes not yet
          built) the call fails fast with an error rather than executing an
          unindexed lookup.

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: object
              x-sql-datatype: JSON
              properties:
                last_block_num:
                  type: integer
                  description: HAF''s consistent (last irreversible) block number
                last_block_time:
                  type: string
                  format: date-time
                  description: UTC timestamp of that block
            example:
              last_block_num: 5000000
              last_block_time: '2016-09-15T19:47:21'
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_sync_status;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_sync_status()
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  -- HAF's consistent (last-irreversible) block number; 0 if none yet
  __consistent_block INT := hive.app_get_irreversible_block();
BEGIN
  -- No cache - sync status needs real-time accuracy
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=0"}]', true);

  -- Fail fast during HAF massive sync: hafd.blocks' PK is dropped for the
  -- duration (hive.disable_indexes_of_irreversible), so the blocks_view
  -- lookup below would seq-scan the largest table in the database.
  -- Health-check agents gate on is_instance_ready() before calling APIs;
  -- this guard protects any caller that does not (e.g. a raw haproxy
  -- httpchk) by erroring in milliseconds instead of stalling.
  IF NOT hive.is_instance_ready() THEN
    RAISE EXCEPTION 'HAF instance is not ready (massive sync in progress)'
      USING ERRCODE = '55000';
  END IF;

  RETURN json_build_object(
    'last_block_num', __consistent_block,
    'last_block_time', to_char(
      (SELECT bv.created_at FROM hive.blocks_view bv WHERE bv.num = __consistent_block),
      'YYYY-MM-DD"T"HH24:MI:SS')
  );
END
$$;

RESET ROLE;
