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
    /*
     * RESPONSE STRUCTURE (depends on _group_by_block):
     *
     * Flat mode (_group_by_block = FALSE):
     *   {
     *     "ops": [{block, op, op_in_trx, operation_id, timestamp, trx_id, trx_in_block, virtual_op}, ...],
     *     "next_block_range_begin": INT,
     *     "next_operation_begin": BIGINT_OR_STRING
     *   }
     *
     * Grouped mode (_group_by_block = TRUE):
     *   {
     *     "ops": [],
     *     "ops_by_block": [{block, irreversible, ops: [...], timestamp}, ...],
     *     "next_block_range_begin": INT,
     *     "next_operation_begin": BIGINT_OR_STRING
     *   }
     *
     * WHY two modes: Flat is simpler for clients, grouped provides block metadata
     * and irreversibility status useful for exchanges and services that need to
     * know if blocks might be reorganized.
     */
    WITH
      /*
       * FETCH VIRTUAL OPERATIONS:
       *   Retrieves raw operations from the database via enum_virtual_ops().
       *   Uses JSONB for operation body to enable later transformations.
       */
      pre_result AS (
        SELECT
          _block         AS "block",
          _value::JSONB  AS "op",          -- Operation body as JSONB for manipulation
          _op_in_trx     AS "op_in_trx",
          _operation_id  AS "operation_id", -- Global operation ID (for pagination)
          _timestamp     AS "timestamp",    -- ISO 8601 format
          _trx_id        AS "trx_id",       -- 40-char hex (usually zeros for virtual ops)
          _trx_in_block  AS "trx_in_block",
          _virtual_op    AS "virtual_op"    -- Always TRUE for this endpoint
        FROM hafah_backend.enum_virtual_ops(
          /*
           * TWO'S COMPLEMENT OVERFLOW HANDLING:
           *   JSON numbers can exceed BIGINT range. numeric_to_bigint() converts
           *   safely, handling unsigned 64-bit values via two's complement.
           */
          hafah_backend.numeric_to_bigint(_filter),
          _block_range_begin,
          _block_range_end,
          _operation_begin,
          _limit,
          _include_reversible,
          __actual_last_irreversible_block_num
        )
      ),
      /*
       * PAGINATION CURSOR CALCULATION:
       *   For cursor-based pagination, we need to tell the client where to continue.
       *   This finds the next virtual operation after the current result set.
       *
       *   The cursor has two components:
       *   1. next_block_range_begin: Which block to start from
       *   2. next_operation_begin: Which operation ID to start from
       *
       *   WHY cursor pagination: More efficient than offset pagination for large
       *   datasets. Client can resume exactly where they left off without re-scanning.
       */
      pag AS (
        WITH pre_result_in AS (
          SELECT
            (
              CASE
                /*
                 * If we returned exactly _limit results, there may be more in the same block.
                 * Otherwise, continue from _block_range_end (caller's requested end).
                 */
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
        /*
         * Find the NEXT virtual operation after our last result.
         * This becomes the cursor for the client's next request.
         */
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
         * NEXT_BLOCK_RANGE_BEGIN:
         *   The block number where the client should start their next request.
         *
         *   COALESCE PATTERN:
         *   1. If pag CTE found a next operation → use that block number
         *   2. Otherwise:
         *      - If _block_range_end > last block in DB → return 0 (no more data)
         *      - Else → return _block_range_end (continue from where we stopped)
         *
         *   WHY 0: Signals "no more data" to the client. They should stop paginating.
         */
        COALESCE(
          (SELECT block_num FROM pag),  -- First choice: next op's block
          (
            CASE
              WHEN _block_range_end > (SELECT num FROM hive.blocks_view ORDER BY num DESC LIMIT 1)
                THEN 0  -- Past end of blockchain, no more data
              ELSE _block_range_end  -- More blocks exist, continue from here
            END
          )
        ) AS next_block_range_begin,
        /*
         * NEXT_OPERATION_BEGIN:
         *   The operation ID where the client should start their next request.
         *
         *   IEEE 754 SAFE INTEGER HANDLING:
         *   json_stringify_bigint() checks if value exceeds JavaScript's safe integer
         *   range (2^53 - 1 = 9007199254740991). Values above this are returned as
         *   strings to prevent precision loss in JSON parsers.
         *
         *   COALESCE PATTERN:
         *   1. If next op is in a NEW block (>= _block_range_end) → return 0
         *      (client should use next_block_range_begin, not operation ID)
         *   2. If next op is in SAME block range → return the operation ID
         *   3. If no next op found → return 0
         */
        hafah_backend.json_stringify_bigint(
          COALESCE(
            (
              CASE
                WHEN (SELECT block_num FROM pag) >= _block_range_end
                  THEN 0  -- At block boundary, use next_block_range_begin instead
                ELSE (SELECT id FROM pag)  -- Continue from this operation ID
              END
            ),
            0  -- No more operations found
          )
        ) AS next_operation_begin,
        /*
         * OPS (FLAT MODE):
         *   Array of operation objects when _group_by_block = FALSE.
         *   Each operation is a flat JSON object with all metadata.
         *
         *   Output: [{block, op, op_in_trx, operation_id, timestamp, trx_id, trx_in_block, virtual_op}, ...]
         *
         *   WHY CASE: Only populate this field in flat mode. In grouped mode,
         *   return empty array (ops_by_block will be populated instead).
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
                    /*
                     * IEEE 754 SAFE INTEGER FOR OPERATION_ID:
                     *   Operation IDs can be very large (billions of operations).
                     *   json_stringify_bigint() returns string if > 9007199254740991
                     *   to prevent JavaScript precision loss.
                     *
                     *   Example:
                     *   - 1234567890 → returned as number: 1234567890
                     *   - 9007199254740992 → returned as string: "9007199254740992"
                     */
                    hafah_backend.json_stringify_bigint(s.operation_id) AS "operation_id",
                    s.timestamp,
                    s.trx_id,
                    s.trx_in_block,
                    s.virtual_op
                  FROM pre_result s
                ) AS res
              )
            )
            ELSE (SELECT ARRAY[]::JSONB[])  -- Empty in grouped mode
          END
        ) AS ops,
        /*
         * OPS_BY_BLOCK (GROUPED MODE):
         *   Array of block objects when _group_by_block = TRUE.
         *   Groups operations by block and includes block-level metadata.
         *
         *   Output structure:
         *   [
         *     {
         *       "block": 12345,
         *       "irreversible": true,      -- FALSE if block may be reorganized
         *       "ops": [{op}, {op}, ...],  -- All operations in this block
         *       "timestamp": "2024-01-15T12:30:45"  -- Block timestamp
         *     },
         *     ...
         *   ]
         *
         *   WHY grouped mode: Exchanges and services need to know if blocks are
         *   finalized (irreversible). Grouping by block makes this clear.
         */
        (
          CASE
            WHEN _group_by_block = TRUE THEN (
              SELECT ARRAY(
                SELECT to_jsonb(grouped)
                FROM (
                  SELECT
                    ds.block                AS "block",
                    /*
                     * IRREVERSIBILITY FLAG:
                     *   __irr_num is set to last irreversible block number when
                     *   _include_reversible = TRUE, or max int (all irreversible) otherwise.
                     *
                     *   block <= __irr_num → block is confirmed, won't be reorganized
                     *   block > __irr_num → block may still be reverted
                     *
                     *   WHY important: Exchanges should wait for irreversibility
                     *   before crediting deposits to prevent double-spend attacks.
                     */
                    (ds.block <= __irr_num) AS "irreversible",
                    /*
                     * array_agg: Collects all operations in this block into an array.
                     * PostgreSQL GROUP BY aggregates all rows with same block number.
                     */
                    array_agg(ds)           AS "ops",
                    /*
                     * BLOCK TIMESTAMP:
                     *   All operations in a block share the same timestamp.
                     */
                    MIN(ds.timestamp) AS "timestamp"
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
                  ORDER BY ds.block ASC  -- Blocks in ascending order
                ) AS grouped
              )
            )
            ELSE (SELECT ARRAY[]::JSONB[])  -- Empty in flat mode
          END
        ) AS ops_by_block
    ) AS result
  );
END
$$;

RESET ROLE;
