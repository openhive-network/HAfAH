SET ROLE hafah_owner;

/*
 * virtual_ops.sql: JSON formatter for enum_virtual_ops JSON-RPC response.
 *
 * Called by: hafah_endpoints.call_enum_virtual_ops() in dispatcher.sql
 *
 * JSON-RPC Method: account_history_api.enum_virtual_ops
 *
 * Formats virtual operations with pagination support. Supports two modes:
 *   - Flat mode: Returns operations in a flat array
 *   - Grouped mode: Returns operations grouped by block with irreversibility info
 */

/*
 * ===================================================================================
 * enum_virtual_ops_json
 * ===================================================================================
 * PURPOSE: Format virtual operations as JSONB for JSON-RPC response with pagination.
 *
 * DATA FLOW:
 *   1. Set cache headers based on block range reversibility
 *   2. Retrieve virtual operations via enum_virtual_ops()
 *   3. Calculate pagination info (next_block_range_begin, next_operation_begin)
 *   4. Format operations based on _group_by_block:
 *      - FALSE: Flat array in 'ops' key
 *      - TRUE: Grouped array in 'ops_by_block' key with block metadata
 *
 * PARAMETERS:
 *   - _filter: Bitmask filter for operation types (NUMERIC for large values)
 *   - _block_range_begin: Start of block range (inclusive)
 *   - _block_range_end: End of block range (exclusive)
 *   - _operation_begin: Starting operation ID for pagination
 *   - _limit: Maximum operations to return
 *   - _include_reversible: Include reversible blocks
 *   - _group_by_block: Group results by block number
 *
 * RETURNS: JSONB with ops/ops_by_block array and pagination fields
 */
CREATE OR REPLACE FUNCTION hafah_backend.enum_virtual_ops_json(
    _filter             NUMERIC,
    _block_range_begin  INT,
    _block_range_end    INT,
    _operation_begin    BIGINT,
    _limit              INT,
    _include_reversible BOOLEAN,
    _group_by_block     BOOLEAN
)
RETURNS JSONB
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __irr_num                           INT;
  __actual_last_irreversible_block_num INT;
BEGIN
  SELECT hive.app_get_irreversible_block() INTO __actual_last_irreversible_block_num;

  /*
   * Cache Control:
   *   - All blocks irreversible: cache for 1 year
   *   - Contains reversible blocks: cache for 3 seconds
   */
  IF _block_range_end <= __actual_last_irreversible_block_num THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  /*
   * Irreversibility Marker:
   *   Used for ops_by_block mode to mark blocks as reversible/irreversible
   *   Default to max int (all irreversible) unless group_by_block with reversible
   */
  __irr_num := (x'7fffffff'::BIGINT::INT);
  IF _include_reversible = TRUE AND _group_by_block = TRUE THEN
    __irr_num := __actual_last_irreversible_block_num;
  END IF;

  RETURN (
    WITH
      /*
       * Fetch and format virtual operations
       */
      pre_result AS (
        SELECT
          _block         AS "block",
          _value::JSONB  AS "op",
          _op_in_trx     AS "op_in_trx",
          _operation_id  AS "operation_id",
          _timestamp     AS "timestamp",
          _trx_id        AS "trx_id",
          _trx_in_block  AS "trx_in_block",
          _virtual_op    AS "virtual_op"
        FROM hafah_backend.enum_virtual_ops(
          hafah_backend.numeric_to_bigint(_filter),
          _block_range_begin,
          _block_range_end,
          _operation_begin,
          _limit,
          _include_reversible
        )
      ),
      /*
       * Calculate Pagination:
       *   Find the next virtual operation after current results for cursor
       */
      pag AS (
        WITH pre_result_in AS (
          SELECT
            (
              CASE
                WHEN (SELECT COUNT(*) FROM pre_result) = _limit
                  THEN pre_result.block
                ELSE _block_range_end
              END
            ) AS blk,
            pre_result.operation_id AS op_id
          FROM pre_result
          WHERE pre_result.operation_id = (SELECT MAX(pre_result.operation_id) FROM pre_result)
          LIMIT 1
        )
        SELECT o.block_num, o.id
        FROM hive.operations_view o
        JOIN hafd.operation_types ot ON o.op_type_id = ot.id
        WHERE
          ot.is_virtual = TRUE
          AND o.block_num >= (SELECT blk FROM pre_result_in)
          AND o.id > (SELECT op_id FROM pre_result_in)
        ORDER BY o.block_num, o.id
        LIMIT 1
      )

    SELECT to_jsonb(result)
    FROM (
      SELECT
        /*
         * next_block_range_begin:
         *   Block to start from in next request, or 0 if past end
         */
        COALESCE(
          (SELECT block_num FROM pag),
          (
            CASE
              WHEN _block_range_end > (SELECT num FROM hafd.blocks ORDER BY num DESC LIMIT 1)
                THEN 0
              ELSE _block_range_end
            END
          )
        ) AS next_block_range_begin,
        /*
         * next_operation_begin:
         *   Operation ID to start from, or 0 if at block boundary
         */
        hafah_backend.json_stringify_bigint(
          COALESCE(
            (
              CASE
                WHEN (SELECT block_num FROM pag) >= _block_range_end
                  THEN 0
                ELSE (SELECT id FROM pag)
              END
            ),
            0
          )
        ) AS next_operation_begin,
        /*
         * ops (flat mode):
         *   Array of operations when _group_by_block = FALSE
         */
        (
          CASE
            WHEN _group_by_block = FALSE THEN (
              SELECT ARRAY(
                SELECT to_jsonb(res)
                FROM (
                  SELECT
                    s.block,
                    s.op,
                    s.op_in_trx,
                    hafah_backend.json_stringify_bigint(s.operation_id) AS "operation_id",
                    s.timestamp,
                    s.trx_id,
                    s.trx_in_block,
                    s.virtual_op
                  FROM pre_result s
                ) AS res
              )
            )
            ELSE (SELECT ARRAY[]::JSONB[])
          END
        ) AS ops,
        /*
         * ops_by_block (grouped mode):
         *   Array of block objects when _group_by_block = TRUE
         *   Each block contains: block number, irreversible flag, ops array, timestamp
         */
        (
          CASE
            WHEN _group_by_block = TRUE THEN (
              SELECT ARRAY(
                SELECT to_jsonb(grouped)
                FROM (
                  SELECT
                    ds.block                AS "block",
                    (ds.block <= __irr_num) AS "irreversible",
                    array_agg(ds)           AS "ops",
                    (
                      SELECT pr.timestamp
                      FROM pre_result pr
                      WHERE pr.block = ds.block
                      ORDER BY pr.operation_id ASC
                      LIMIT 1
                    ) AS "timestamp"
                  FROM (
                    SELECT
                      s.block,
                      s.op,
                      s.op_in_trx,
                      hafah_backend.json_stringify_bigint(s.operation_id) AS "operation_id",
                      s.timestamp,
                      s.trx_id,
                      s.trx_in_block,
                      s.virtual_op
                    FROM pre_result s
                  ) AS ds
                  GROUP BY ds.block
                  ORDER BY ds.block ASC
                ) AS grouped
              )
            )
            ELSE (SELECT ARRAY[]::JSONB[])
          END
        ) AS ops_by_block
    ) AS result
  );
END
$$;

RESET ROLE;
