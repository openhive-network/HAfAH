SET ROLE hafah_owner;

/*
 * account_history.sql: get_account_history JSON-RPC method implementation.
 *
 * Called by: hafah_backend.ah_get_account_history_json() in formatters/account_history.sql
 *
 * JSON-RPC Method: account_history_api.get_account_history
 *
 * Returns operation history for a specific account with filtering and pagination.
 *
 * 128-BIT OPERATION TYPE FILTER:
 *   Hive uses a 128-bit bitmask to filter operation types. Each bit position
 *   corresponds to an operation type ID. The filter is split into two 64-bit
 *   parts for JSON transmission:
 *
 *     _filter_low:  Bits 0-63  (operation types 0-63)
 *     _filter_high: Bits 64-127 (operation types 64-127)
 *
 *   Example: To filter for vote_operation (type 0) and comment_operation (type 1):
 *     _filter_low = 3 (binary: 11), _filter_high = 0
 *
 *   NULL filter means "all types". Zero filter means "no types" (empty result).
 *
 *   The translate_get_account_history_filter() function converts this bitmask
 *   to an array of operation type IDs for use in SQL queries.
 */

/*
 * ===================================================================================
 * ah_get_account_history
 * ===================================================================================
 * PURPOSE: Retrieve account operation history with filtering by operation type.
 *
 * IRREVERSIBLE DATA ONLY:
 *   Reads the hafd.* base tables and returns operations in blocks up to
 *   hive.app_get_irreversible_block(). The JSON-RPC include_reversible argument
 *   is accepted by the dispatcher but does not reach this function: even when
 *   it is true, only irreversible operations are returned.
 *
 * DATA FLOW:
 *   1. Validate input parameters (limit, start/limit relationship)
 *   2. Handle empty filter case (return empty)
 *   3. Translate filter bitmask to operation type IDs
 *   4. Resolve account name to ID
 *   5. Select the page from hafd.account_operations, newest first
 *   6. Join each page row once to hafd.operations (with its type),
 *      hafd.transactions for the hash and hafd.blocks for the timestamp
 *   7. Return formatted results ordered by operation sequence
 *
 * PLAN CHOICE (filtered calls):
 *   Two ways to read a filtered page, and which is fast depends on how common
 *   the requested types are for this account:
 *     - walk hive_account_operations_uq1 (account_id, account_op_seq_no)
 *       backwards and stop after _limit matches: about _limit * N / M rows
 *       visited, N = the account's irreversible operations up to _start,
 *       M = the matches among them;
 *     - read every match through hive_account_operations_account_id_op_type_id_idx
 *       and sort: about M rows.
 *   They cost the same at M = sqrt(_limit * N). The planner cannot judge M: it
 *   multiplies the account's and the types' frequencies, and nothing records
 *   how often a type occurs for one account. So M is counted, up to that
 *   threshold, by hafah_backend.account_op_types_are_rare (backend/utilities/paging.sql),
 *   and the page query takes the branch the count selects. The walk tests the
 *   types with IS TRUE, which no index can serve, so a misestimate cannot turn
 *   it into a full read and sort of a common type.
 *
 *   plan_cache_mode = force_custom_plan plans the page query for every call
 *   with the account, the filter and the branch as constants: the branch not
 *   taken folds away, and the estimates are the account's own.
 *
 * PARAMETERS:
 *   - _filter_low: Low 64 bits of operation type bitmask
 *   - _filter_high: High 64 bits of operation type bitmask
 *   - _account: Account name to query
 *   - _start: Starting operation sequence number (descending)
 *   - _limit: Maximum operations to return
 *   - _is_legacy_style: Format operations in legacy style
 *
 * RETURNS: Table of account operations with metadata
 */
CREATE OR REPLACE FUNCTION hafah_backend.ah_get_account_history(
    _filter_low         BIGINT,
    _filter_high        BIGINT,
    _account            VARCHAR,
    _start              BIGINT,
    _limit              BIGINT,
    _is_legacy_style    BOOLEAN
)
RETURNS TABLE(
    _trx_id       TEXT,
    _block        INT,
    _trx_in_block BIGINT,
    _op_in_trx    BIGINT,
    _virtual_op   BOOLEAN,
    _timestamp    TEXT,
    _value        JSONB,
    _operation_id INT
)
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS $$
DECLARE
  __resolved_filter       SMALLINT[];  -- Array of operation type IDs from bitmask (NULL = all types)
  __account_id            INT;         -- Resolved numeric account ID
  __upper_operation_id    BIGINT;      -- First operation id past the last irreversible block
  __last_seq              INT;         -- Highest seq the page can return
  __rare_types            BOOLEAN := FALSE;  -- TRUE: read all matches by type and sort
BEGIN
  /*
   * INPUT VALIDATION:
   *   - Limit must be <= 1000 (API maximum)
   *   - Start must be >= limit-1 (ensures valid window)
   */
  PERFORM hafah_backend.validate_limit(_limit, 1000);
  PERFORM hafah_backend.validate_start_limit(_start, _limit);

  /*
   * EMPTY FILTER CHECK:
   *   128-bit filter split into low/high 64-bit parts:
   *   - NULL + NULL = all types (no filtering)
   *   - 0 + 0 = no types (return empty result)
   *   - Any non-zero = specific types
   *
   * WHY COALESCE: Handle NULL values in addition (NULL + 0 = NULL, not 0)
   */
  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL))
     AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    -- WHY: Zero filter explicitly means "no operations" - fast exit
    RETURN;
  END IF;

  /*
   * BITMASK TO TYPE ID TRANSLATION:
   *   Convert 128-bit bitmask to array of SMALLINT operation type IDs.
   *   Example: filter_low=5 (binary 101) → [0, 2] (types at bit positions 0 and 2)
   *
   *   See: backend/utilities/bit_operations.sql for implementation
   */
  __resolved_filter := hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high);

  -- Every operation of block N has an id below operation_id(N + 1, 0)
  __upper_operation_id := hafd.operation_id(hive.app_get_irreversible_block() + 1, 0);

  -- TIMING: Resolved once here, not in the query, so the page query plans with a constant
  __account_id := (SELECT ha.id FROM hafd.accounts ha WHERE ha.name = _account);

  IF __resolved_filter IS NOT NULL THEN
    -- The page reads seq 0 up to the newest irreversible operation at or below _start
    __last_seq := (
      SELECT ao.account_op_seq_no
      FROM hafd.account_operations ao
      WHERE ao.account_id = __account_id
        AND ao.account_op_seq_no <= _start
        AND ao.operation_id < __upper_operation_id
      ORDER BY ao.account_op_seq_no DESC
      LIMIT 1
    );

    __rare_types := hafah_backend.account_op_types_are_rare(
      __resolved_filter::INT[], __account_id, 0, __last_seq, _limit::INT
    );
  END IF;

  RETURN QUERY
    SELECT
      /*
       * TRANSACTION ID:
       *   - Regular ops: 40-char hex hash from hafd.transactions
       *   - Virtual ops: Use placeholder (40 zeros)
       *
       * NOTE: trx_in_block < 0 indicates a virtual operation (no real transaction)
       */
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN '0000000000000000000000000000000000000000'
          ELSE encode(ht.trx_hash, 'hex')
        END
      ) AS _trx_id,
      blk.block_num AS _block,
      /*
       * TRANSACTION IN BLOCK:
       *   - Regular ops: 0-based index within block
       *   - Virtual ops: 4294967295 (max uint32, signals "no transaction")
       */
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN 4294967295  -- WHY: Max uint32 = "no transaction" marker
          ELSE ho.trx_in_block
        END
      ) AS _trx_in_block,
      ho.op_pos AS _op_in_trx,
      ho.virtual_op AS _virtual_op,
      /*
       * TIMESTAMP FORMATTING:
       *   Block timestamp in ISO 8601 format without quotes.
       *   btrim removes quotes added by to_json().
       */
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS _timestamp,
      /*
       * OPERATION BODY FORMAT:
       *   - Legacy: Old format with type as string key {"vote": {...}}
       *   - New: Structured format {"type": "vote_operation", "value": {...}}
       */
      (
        CASE
          WHEN _is_legacy_style
            THEN hive.get_legacy_style_operation(hafd._operation_from_jsonb(ho.body))::JSONB
          ELSE ho.body
        END
      ) AS _value,
      page.account_op_seq_no AS _operation_id
    FROM (
      /*
       * PAGE SELECTION:
       *   Newest first from _start, at most _limit rows, irreversible only.
       *   Exactly one branch runs; the custom plan folds the other away.
       */
      (
        -- Walk uq1: unfiltered calls, and filters whose types are common for the account
        SELECT ao.operation_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types
          AND ao.account_id = __account_id
          AND ao.account_op_seq_no <= _start
          AND ao.operation_id < __upper_operation_id
          AND (__resolved_filter IS NULL OR (ao.op_type_id = ANY(__resolved_filter)) IS TRUE)
        ORDER BY ao.account_op_seq_no DESC  -- WHY: Most recent first
        LIMIT _limit
      )
      UNION ALL
      (
        -- Rare types: every match through the (account_id, op_type_id) index, then sort
        SELECT rare.operation_id, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
            AND ao.account_id = __account_id
            AND ao.op_type_id = ANY(__resolved_filter)
            AND ao.account_op_seq_no <= _start
            AND ao.operation_id < __upper_operation_id
          OFFSET 0  -- WHY: Plan the fetch of all matches on its own, not as an ordered walk
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT _limit
      )
      LIMIT _limit  -- WHY: Lets the planner see the page holds at most _limit rows
    ) page
    CROSS JOIN LATERAL (SELECT hafd.operation_id_to_block_num(page.operation_id) AS block_num) blk
    -- One primary-key probe per page row: body, op_pos, trx_in_block, is_virtual
    JOIN hafah_backend.helper_operations_view ho ON ho.id = page.operation_id
    JOIN hafd.blocks hb ON hb.num = blk.block_num  -- WHY: Get block timestamp
    -- Virtual ops (trx_in_block = -1) match no transaction
    LEFT JOIN LATERAL (
      -- LIMIT 1: a position holds one transaction (its index is not declared unique)
      SELECT tx.trx_hash FROM hafd.transactions tx
      WHERE tx.block_num = blk.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
    ORDER BY page.account_op_seq_no ASC;  -- WHY: Return in ascending sequence order
END
$$;

RESET ROLE;
