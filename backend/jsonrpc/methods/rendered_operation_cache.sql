SET ROLE hafah_owner;

/*
 * rendered_operation_cache.sql: fills hafah_backend.rendered_operation_cache
 * (db/hafah_app.sql), which ah_get_account_history and
 * ah_get_account_history_json read.
 *
 * Called by: scripts/install_app.sh after the functions and grants exist; by an
 * operator once the node's irreversible head passes an operation to cache.
 */

/*
 * ===================================================================================
 * refresh_rendered_operation_cache
 * ===================================================================================
 * PURPOSE: Render the get_account_history inner objects of selected irreversible
 *          operations once and store them.
 *
 * SELECTION:
 *   - _operation_ids NULL: operations of the types named in _op_types whose stored
 *     body exceeds _min_bytes. The default is the HF23 hardfork_hive operation
 *     (13.8 MB of JSON), exactly one operation on mainnet, none below block
 *     41818752. hafd.operations is read through its op_type_id index; the types
 *     must be rare, as a size scan of all operations is infeasible.
 *   - _operation_ids given: exactly those operations; _op_types and _min_bytes
 *     are ignored.
 *   Operations past the last irreversible block are never cached, so an entry
 *   never goes stale.
 *
 * RENDERING:
 *   The expressions repeat those of ah_get_account_history
 *   (methods/account_history.sql) and ah_get_account_history_json
 *   (formatters/account_history.sql); keep them in step, since the formatter
 *   splices the stored text verbatim and the response must be byte-identical.
 *
 * PARAMETERS:
 *   - _op_types: Operation type names (hafd.operation_types.name)
 *   - _min_bytes: Stored body size (pg_column_size) an operation must exceed
 *   - _operation_ids: Explicit operation ids, overriding the two above
 *
 * RETURNS: Number of operations in the cache after the refresh
 */
CREATE OR REPLACE FUNCTION hafah_backend.refresh_rendered_operation_cache(
    _op_types           TEXT[] = ARRAY['hive::protocol::hardfork_hive_operation'],
    _min_bytes          INT = 1000000,
    _operation_ids      BIGINT[] = NULL
)
RETURNS INT
LANGUAGE 'plpgsql' VOLATILE
SET plan_cache_mode = force_custom_plan
AS $$
DECLARE
  -- Every operation of block N has an id below operation_id(N + 1, 0)
  __upper_operation_id BIGINT := hafd.operation_id(hive.app_get_irreversible_block() + 1, 0);
  __ids                BIGINT[] := _operation_ids;
  __op_type_ids        SMALLINT[];
  __count              INT;
BEGIN
  IF __ids IS NULL THEN
    -- TIMING: Resolved first so the scan plans with constant types: the op_type_id
    -- index then serves it, where a subquery's types are planned as a full scan
    __op_type_ids := ARRAY(SELECT ot.id FROM hafd.operation_types ot WHERE ot.name = ANY(_op_types));

    __ids := ARRAY(
      SELECT o.id
      FROM hafd.operations o
      WHERE o.op_type_id = ANY(__op_type_ids)
        AND pg_column_size(o.body_value) > _min_bytes
        AND o.id < __upper_operation_id
    );
  END IF;

  INSERT INTO hafah_backend.rendered_operation_cache (operation_id, legacy_entry, entry)
  SELECT
    r.id,
    -- As ah_get_account_history_json renders the inner object, legacy and new style
    (to_jsonb(legacy) - 'operation_id')::TEXT::JSON,
    jsonb_set(to_jsonb(new_style), ARRAY['operation_id']::TEXT[], '0'::JSONB, FALSE)::TEXT::JSON
  FROM (
    -- As ah_get_account_history selects each page row
    SELECT
      ho.id,
      blk.block_num,
      ho.body,
      ho.op_pos,
      ho.virtual_op,
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN '0000000000000000000000000000000000000000'
          ELSE encode(ht.trx_hash, 'hex')
        END
      ) AS trx_id,
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN 4294967295
          ELSE ho.trx_in_block
        END
      ) AS trx_in_block,
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS created_at
    FROM hafah_backend.helper_operations_view ho
    CROSS JOIN LATERAL (SELECT hafd.operation_id_to_block_num(ho.id) AS block_num) blk
    JOIN hafd.blocks hb ON hb.num = blk.block_num
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash FROM hafd.transactions tx
      WHERE tx.block_num = blk.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
    WHERE ho.id = ANY(__ids)
      AND ho.id < __upper_operation_id
  ) r
  -- Column names, order and types as the formatter's ops row
  CROSS JOIN LATERAL (
    SELECT
      r.block_num::INT AS "block",
      hive.get_legacy_style_operation(hafd._operation_from_jsonb(r.body))::JSONB AS "op",
      r.op_pos::BIGINT AS "op_in_trx",
      r.created_at AS "timestamp",
      r.trx_id AS "trx_id",
      r.trx_in_block::BIGINT AS "trx_in_block",
      r.virtual_op AS "virtual_op",
      0 AS "operation_id"
  ) legacy
  CROSS JOIN LATERAL (
    SELECT
      r.block_num::INT AS "block",
      r.body AS "op",
      r.op_pos::BIGINT AS "op_in_trx",
      r.created_at AS "timestamp",
      r.trx_id AS "trx_id",
      r.trx_in_block::BIGINT AS "trx_in_block",
      r.virtual_op AS "virtual_op",
      0 AS "operation_id"
  ) new_style
  ON CONFLICT (operation_id) DO UPDATE
    SET legacy_entry = EXCLUDED.legacy_entry, entry = EXCLUDED.entry;

  -- WHY: A handful of rows never reaches autovacuum's analyze threshold, and
  -- unanalyzed the table is planned as ~800 rows
  ANALYZE hafah_backend.rendered_operation_cache;

  SELECT count(*) INTO __count FROM hafah_backend.rendered_operation_cache;
  RETURN __count;
END
$$;

RESET ROLE;
