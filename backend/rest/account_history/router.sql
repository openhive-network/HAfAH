SET ROLE hafah_owner;

/*
 * router.sql: Account history request router.
 *
 * Routes account history requests to appropriate filtering function based on
 * participation_mode and filter parameters.
 *
 * Called by: hafah_endpoints.get_account_operations() in endpoints/accounts/get_account_operations.sql
 *
 * REST Endpoint: GET /accounts/{account-name}/operations
 *
 * Routing Logic:
 *   - No filters            → account_history_default()
 *   - Operations only       → account_history_by_operations()
 *   - Include single acct   → account_history_include_account()
 *   - Include multi accts   → account_history_including_accounts()
 *   - Exclude single acct   → account_history_exclude_account()
 *   - Exclude multi accts   → account_history_excluding_accounts()
 */

/*
 * ===================================================================================
 * get_ops_by_account
 * ===================================================================================
 * PURPOSE: Main entry point for account history queries. Routes to specific
 *          implementation based on filtering parameters.
 *
 * PARAMETERS:
 *   _account_id         - Account ID to get operations for
 *   _filter_account_ids - Array of account IDs to filter by (NULL array means no filter)
 *   _operations         - Array of operation type IDs to filter by (NULL means no filter)
 *   _from_block         - Starting block number
 *   _to_block           - Ending block number
 *   _page               - Page number for pagination
 *   _body_limit         - Maximum size for operation body (-1 for unlimited)
 *   _limit              - Number of results per page
 *   _participation_mode - Filter mode: 'all', 'include', or 'exclude'
 *
 * RETURNS: Account operation history with pagination info
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

  -- flags
  _filter_by_account_ids BOOLEAN := (_filter_account_ids != ARRAY[NULL]::INT[]);
  _filter_by_single_acc  BOOLEAN := (CASE WHEN (_filter_account_ids != ARRAY[NULL]::INT[]) AND (array_length(_filter_account_ids, 1) = 1) THEN TRUE ELSE FALSE END);
  _filter_by_op          BOOLEAN := (_operations IS NOT NULL);
BEGIN
  CASE
    -- If no filters are applied, use the default account history function
    WHEN ((_participation_mode = 'all') AND (NOT _filter_by_op)) OR ((_participation_mode != 'all') AND (NOT _filter_by_account_ids) AND (NOT _filter_by_op) ) THEN
      _result := hafah_backend.account_history_default(
          _account_id,
          _from_block,
          _to_block,
          _page,
          _body_limit,
          _limit
      );

    -- If only operations are filtered, use the account history by operations function
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
    -- If accounts are filtered, use the account history by accounts function (include account)
    WHEN (_participation_mode = 'include') AND (_filter_by_account_ids) AND (_filter_by_single_acc) THEN
      _result := hafah_backend.account_history_include_account(
        _account_id,
        _operations,
        _filter_account_ids[1],
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );
    -- If accounts are filtered, use the account history by accounts function (include accounts)
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
    -- If accounts are filtered, use the account history by accounts function (exclude account)
    WHEN (_participation_mode = 'exclude') AND (_filter_by_account_ids) AND (_filter_by_single_acc) THEN
      _result := hafah_backend.account_history_exclude_account(
        _account_id,
        _operations,
        _filter_account_ids[1],
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );
    -- If accounts are filtered, use the account history by accounts function (excluding accounts)
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
      RAISE EXCEPTION 'Invalid parameters';
  END CASE;

  RETURN _result;
END
$$;

RESET ROLE;
