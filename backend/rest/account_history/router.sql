SET ROLE hafah_owner;

/*
 * ===================================================================================
 * router.sql: Account history request router
 * ===================================================================================
 * Main entry point for REST account operation history queries.
 *
 * Called by: hafah_endpoints.get_ops_by_account() in endpoints/accounts/get_ops_by_account.sql
 * REST Endpoint: GET /accounts/{account-name}/operations
 *
 * ROUTING LOGIC:
 * ─────────────────────────────────────────────────────────────────────────────────────
 *   Filter Combination                    │ Routes To
 * ─────────────────────────────────────────────────────────────────────────────────────
 *   No filters (mode='all', no ops)       │ account_history_default()
 *   Operations only (no account filter)   │ account_history_by_operations()
 *   Include + single account              │ account_history_include_account()
 *   Include + multiple accounts           │ account_history_including_accounts()
 *   Exclude + single account              │ account_history_exclude_account()
 *   Exclude + multiple accounts           │ account_history_excluding_accounts()
 * ─────────────────────────────────────────────────────────────────────────────────────
 *
 * WHY 6 SEPARATE IMPLEMENTATIONS?
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Each filter strategy requires different query patterns for optimal performance:
 *
 *   1. DEFAULT: Simple query on account_operations_view with no filters.
 *      Uses direct COUNT for total operations (fast on indexed column).
 *
 *   2. BY_OPERATIONS: Filters by op_type_id using = ANY(array).
 *      COUNT query includes the same filter for accurate totals.
 *
 *   3. INCLUDE/EXCLUDE ACCOUNT(S): Filters on transacting_account_id column.
 *      Uses "sliding window" pagination (max 10 pages per batch) because
 *      counting all matching operations would be too expensive.
 *      Returns adjusted from_block for cursor-based continuation.
 *
 * A single function with conditional logic would produce suboptimal query plans
 * because PostgreSQL cannot optimize away unused JOINs at plan time.
 * ─────────────────────────────────────────────────────────────────────────────────────
 */

/*
 * ===================================================================================
 * FUNCTION: get_ops_by_account
 * ===================================================================================
 * PURPOSE: Main entry point for account history queries. Routes to specific
 *          implementation based on filtering parameters.
 *
 * PARAMETERS:
 *   _account_id         - Account ID to get operations for (from hive.accounts_view)
 *   _filter_account_ids - Array of account IDs to filter by (NULL array means no filter)
 *   _operations         - Array of operation type IDs to filter by (NULL means all types)
 *   _from_block         - Starting block number (inclusive)
 *   _to_block           - Ending block number (inclusive)
 *   _page               - Page number for pagination (1-indexed, NULL for latest)
 *   _body_limit         - Maximum size for operation body (-1 for unlimited)
 *   _limit              - Number of results per page (max 1000)
 *   _participation_mode - Filter mode: 'all', 'include', or 'exclude'
 *
 * RETURNS: hafah_backend.account_operation_history composite type containing:
 *   - total_operations: Count of operations matching filters (within current batch for include/exclude)
 *   - total_pages: Number of pages available
 *   - block_range: Effective from/to block range (may be adjusted for cursor pagination)
 *   - operations_result: Array of operation records
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_account(
    _account_id INT,
    _filter_account_ids INT [],
    _operations INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT,
    _participation_mode hafah_backend.participation_mode
)
RETURNS hafah_backend.account_operation_history -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  _result hafah_backend.account_operation_history;

  /*
   * ROUTING FLAGS
   * ─────────────────────────────────────────────────────────────────────────────
   * These boolean flags determine which filter implementation to invoke.
   * Evaluated once at function start to avoid repeated array comparisons.
   */
  -- TRUE if any account filter IDs were provided (array is not [NULL])
  _filter_by_account_ids BOOLEAN := (_filter_account_ids != ARRAY[NULL]::INT[]);
  -- TRUE if exactly one account filter ID was provided (uses scalar comparison for better performance)
  _filter_by_single_acc  BOOLEAN := (CASE WHEN (_filter_account_ids != ARRAY[NULL]::INT[]) AND (array_length(_filter_account_ids, 1) = 1) THEN TRUE ELSE FALSE END);
  -- TRUE if operation type filter was provided
  _filter_by_op          BOOLEAN := (_operations IS NOT NULL);
BEGIN
  /*
   * ROUTING DECISION TREE
   * ─────────────────────────────────────────────────────────────────────────────
   * Routes to specialized implementation based on filter combination.
   * Order matters: more specific conditions checked first.
   */
  CASE
    /*
     * ROUTE 1: DEFAULT (no filters)
     * Uses simple query with direct COUNT for fast pagination calculation.
     * Condition: mode='all' with no op filter, OR mode!='all' but no account or op filter
     */
    WHEN ((_participation_mode = 'all') AND (NOT _filter_by_op)) OR ((_participation_mode != 'all') AND (NOT _filter_by_account_ids) AND (NOT _filter_by_op) ) THEN
      _result := hafah_backend.account_history_default(
          _account_id,
          _from_block,
          _to_block,
          _page,
          _body_limit,
          _limit
      );

    /*
     * ROUTE 2: BY OPERATIONS (operation type filter only)
     * Filters using op_type_id = ANY(_operations) for efficient type matching.
     * COUNT query includes same filter for accurate total calculation.
     */
    WHEN ((_participation_mode = 'all') AND (_filter_by_op)) OR ((_participation_mode != 'all') AND (NOT _filter_by_account_ids) AND (_filter_by_op)) THEN
      _result := hafah_backend.account_history_by_operations(
        _account_id,
        _operations,
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );

    /*
     * ROUTE 3: INCLUDE SINGLE ACCOUNT
     * Uses scalar comparison (transacting_account_id = id) for best index usage.
     * Implements sliding window pagination with max 10 pages per batch.
     */
    WHEN (_participation_mode = 'include') AND (_filter_by_account_ids) AND (_filter_by_single_acc) THEN
      _result := hafah_backend.account_history_include_account(
        _account_id,
        _operations,
        _filter_account_ids[1],  -- Extract single ID from array
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );

    /*
     * ROUTE 4: INCLUDE MULTIPLE ACCOUNTS
     * Uses array comparison (transacting_account_id = ANY(ids)) for multi-account match.
     * Same sliding window pagination as single account variant.
     */
    WHEN (_participation_mode = 'include') AND (_filter_by_account_ids) AND (NOT _filter_by_single_acc) THEN
      _result := hafah_backend.account_history_including_accounts(
        _account_id,
        _operations,
        _filter_account_ids,
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );

    /*
     * ROUTE 5: EXCLUDE SINGLE ACCOUNT
     * Uses scalar negation (transacting_account_id != id).
     * Sliding window pagination handles potentially large result sets.
     */
    WHEN (_participation_mode = 'exclude') AND (_filter_by_account_ids) AND (_filter_by_single_acc) THEN
      _result := hafah_backend.account_history_exclude_account(
        _account_id,
        _operations,
        _filter_account_ids[1],  -- Extract single ID from array
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );

    /*
     * ROUTE 6: EXCLUDE MULTIPLE ACCOUNTS
     * Uses array negation (transacting_account_id != ANY(ids)).
     * Same sliding window pagination as single account variant.
     */
    WHEN (_participation_mode = 'exclude') AND (_filter_by_account_ids) AND (NOT _filter_by_single_acc) THEN
      _result := hafah_backend.account_history_excluding_accounts(
        _account_id,
        _operations,
        _filter_account_ids,
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );

    ELSE
      -- Should not reach here if endpoint validation is working correctly
      RAISE EXCEPTION 'Invalid parameters';
  END CASE;

  RETURN _result;
END
$$;

RESET ROLE;
