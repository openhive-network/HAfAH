SET ROLE hafah_owner;

/*
 * ===================================================================================
 * excluding_accounts.sql: Account history filtered by multiple transacting accounts (exclude)
 * ===================================================================================
 * Called by: hafah_backend.get_ops_by_account() in backend/rest/account_history/router.sql
 *
 * Used when: participation_mode='exclude' with MORE THAN ONE account in the filter array
 *
 * DIFFERENCE FROM exclude_account.sql:
 * ─────────────────────────────────────────────────────────────────────────────────────
 *   - exclude_account.sql:    transacting_account_id != _id (scalar)
 *   - excluding_accounts.sql: transacting_account_id != ANY(_ids) (array)
 *
 * IMPORTANT SQL SEMANTICS:
 * ─────────────────────────────────────────────────────────────────────────────────────
 *   != ANY(array) means "not equal to AT LEAST ONE element"
 *   This is equivalent to: NOT (value = ALL(array))
 *   For exclusion logic, this works correctly because:
 *   - If transacting_id matches ANY excluded id, that row is filtered out
 *   - Only rows where transacting_id doesn't match ANY excluded id are returned
 *
 * ALTERNATIVE APPROACHES (commented out in code):
 *   - NOT EXISTS with unnested array: More explicit but potentially slower
 *   - ALL() operator: Would require different logic
 *
 * Uses the same sliding window pagination strategy as include_account.sql.
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: account_history_excluding_accounts
 * ===================================================================================
 * PURPOSE: Retrieve account operations where the transacting account does NOT match
 *          any of the specified accounts. Uses sliding window pagination with max 10 pages.
 *
 * PARAMETERS:
 *   _account_id              - Account ID to get operations for (the "affected" account)
 *   _operations              - Array of operation type IDs to filter by (NULL for all)
 *   _transacting_account_ids - Array of account IDs to EXCLUDE from transacting party
 *   _from_block              - Starting block number (inclusive)
 *   _to_block                - Ending block number (inclusive)
 *   _page                    - Page number for pagination (within current batch)
 *   _body_limit              - Maximum size for operation body (-1 for unlimited)
 *   _limit                   - Number of results per page
 *
 * RETURNS: hafah_backend.account_operation_history with cursor-adjusted block range
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_history_excluding_accounts(
    _account_id INT,
    _operations INT [],
    _transacting_account_ids INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
-- Plan each call with its account and filter: the two-step walk of
-- hive_account_operations_uq1 is fast when the requested types are common for
-- the account, the (account_id, op_type_id) index is fast when they are rare.
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;  -- Sliding window size

  __total_pages INT;
  __min_block_num INT;
  __count INT;
  __rare_types BOOLEAN;  -- TRUE: read all matches by type and sort, FALSE: two steps on uq1 (a plain walk without a type filter)
BEGIN
  /*
   * STEP 1: Calculate sequence range from block range
   */
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);

  -- Rare/common page plan, as in account_history_by_operations; [from_seq, to_seq]
  -- already stops at the last irreversible block
  __rare_types := hafah_backend.account_op_types_are_rare(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1
  );

  /*
   * ===================================================================================
   * CTE: operation_range
   * ===================================================================================
   * Fetch operations where transacting_account_id does NOT match ANY of the excluded accounts.
   *
   * ALTERNATIVE APPROACH (commented out):
   *   The commented excluded_ids CTE with NOT EXISTS would achieve the same result
   *   but may have different performance characteristics depending on array size.
   *   Current approach using != ANY() is more concise.
   *
   * KEY DIFFERENCE: Uses != ANY(_transacting_account_ids) for multi-account exclusion.
   */
  WITH /* excluded_ids AS MATERIALIZED (
    SELECT unnest(_transacting_account_ids) AS id
  ), */
  operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      -- Exactly one branch runs; the custom plan folds the others away
      (
        -- No type filter: walk uq1; the fence keeps the sort-everything plan out of this branch
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types AND _operations IS NULL
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0  -- Filters stay outside, so the planner costs the walk on every account row
        ) walk
        WHERE (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
        AND NOT (walk.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
        AND walk.transacting_account_id IS NOT NULL
        /*
         * Alternative using NOT EXISTS (may perform better for large exclusion lists):
         * AND NOT EXISTS (
         *     SELECT 1 FROM excluded_ids e
         *     WHERE e.id = ao.transacting_account_id
         * )
         */
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        -- Typed, step 1: matching seqs newest first, index-only on uq1 INCLUDE (op_type_id)
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT __rare_types AND _operations IS NOT NULL
          AND s.account_id = _account_id
          AND (s.op_type_id = ANY(_operations)) IS TRUE  -- IS TRUE: no type-index plan
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          OFFSET 0  -- Planned on its own; the LIMIT below stops it after the page
        ) seqs
        -- Step 2: each match's row for the partner filter; LIMIT 1 keeps it a uq1 probe per seq
        CROSS JOIN LATERAL (
          SELECT ao.operation_id, ao.transacting_account_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
        WHERE NOT (ao.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
        AND ao.transacting_account_id IS NOT NULL
        ORDER BY seqs.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        -- Rare types: every match through the (account_id, op_type_id) index, then sort
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
          AND ao.account_id = _account_id
          AND ao.op_type_id = ANY(_operations)
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          AND NOT (ao.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
          AND ao.transacting_account_id IS NOT NULL
          OFFSET 0  -- Plan the fetch of all matches on its own, not as an ordered walk
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
    ) ls
  ),
  /*
   * SLIDING WINDOW PAGINATION CTEs
   * (See include_account.sql for detailed documentation)
   */
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  /*
   * Block boundary handling: fetch all ops from boundary block if needed.
   * Uses same != ANY() filter as operation_range.
   */
  filter_by_op_seq AS MATERIALIZED (
    (
      -- No type filter: walk uq1; the fence keeps the sort-everything plan out of this branch
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types AND _operations IS NULL
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0  -- Filters stay outside, so the planner costs the walk on every account row
      ) walk
      WHERE NOT (walk.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
      AND walk.transacting_account_id IS NOT NULL
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      -- Typed, step 1: matching seqs newest first, index-only on uq1 INCLUDE (op_type_id)
      SELECT ao.operation_id AS id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM (
        SELECT s.account_op_seq_no, s.op_type_id
        FROM hafd.account_operations s
        WHERE NOT __rare_types AND _operations IS NOT NULL
        AND s.account_id = _account_id
        AND (s.op_type_id = ANY(_operations)) IS TRUE  -- IS TRUE: no type-index plan
        AND s.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND s.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY s.account_op_seq_no DESC
        OFFSET 0  -- Planned on its own; the LIMIT below stops it after the page
      ) seqs
      -- Step 2: each match's row for the partner filter; LIMIT 1 keeps it a uq1 probe per seq
      CROSS JOIN LATERAL (
        SELECT ao.operation_id, ao.transacting_account_id
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
        AND ao.account_op_seq_no = seqs.account_op_seq_no
        LIMIT 1
      ) ao
      WHERE NOT (ao.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
      AND ao.transacting_account_id IS NOT NULL
      ORDER BY seqs.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      -- Rare types: every match through the (account_id, op_type_id) index, then sort
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE __rare_types
        AND ao.account_id = _account_id
        AND NOT (ao.transacting_account_id = ANY(_transacting_account_ids))  -- Multi-account exclude
        AND ao.transacting_account_id IS NOT NULL
        AND ao.op_type_id = ANY(_operations)
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        OFFSET 0  -- Plan the fetch of all matches on its own, not as an ordered walk
      ) rare
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit
    )
  ),
  find_all_records_for_page AS (
    SELECT ls.id, ls.block_num, ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT id, block_num, op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT id, block_num, op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  /*
   * JOIN operation details from related tables
   */
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      -- LIMIT 1: a position holds one transaction (its index is not declared unique)
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
      FROM (
        SELECT
          s.body,
          s.block_num,
          s.trx_hash,
          s.op_pos,
          s.op_type_id,
          s.created_at,
          s.is_virtual,
          s.id::TEXT,
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;

  /*
   * CURSOR CALCULATION
   * Adjust from_block for next API call continuation.
   * (See include_account.sql for detailed documentation)
   */
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );

  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;

END
$$;

RESET ROLE;
