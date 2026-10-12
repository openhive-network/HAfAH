SET ROLE hafah_owner;

/*
 * acc_op_types.sql: REST API backend for account-specific operation types.
 *
 * Called by: hafah_endpoints.get_account_operation_types() in endpoints/accounts/get_account_operation_types.sql
 *
 * REST Endpoint: GET /accounts/{account-name}/operation-types
 */

/*
 * ===================================================================================
 * get_acc_op_types
 * ===================================================================================
 * PURPOSE: Retrieve operation types that have been used by a specific account.
 *          Useful for building dynamic filters in account history views.
 *
 * PARAMETERS:
 *   _account_id - Account ID to check operation types for
 *
 * RETURNS: Array of operation type IDs used by the account
 *
 * DATA SOURCES:
 *   - hafd.operation_types: Master list of all operation types
 *   - hafd.account_operations: Account-to-operation index (irreversible operations)
 *
 * NOTES:
 *   - Uses EXISTS subquery for efficient presence check
 *   - Returns only types actually used by this account, not all types
 *   - Useful for UI filter dropdowns (only show relevant operation types)
 *   - Ordered by ID for consistent results
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_acc_op_types(
    _account_id INT
)
RETURNS INT[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  -- Every operation of block N has an id below operation_id(N + 1, 0)
  __upper_operation_id BIGINT := hafd.operation_id(hive.app_get_irreversible_block() + 1, 0);
BEGIN
  -- Aggregate matching type IDs into ordered array
  RETURN array_agg(hot.id ORDER BY hot.id)
  FROM hafd.operation_types hot
  -- EXISTS pattern: More efficient than JOIN for existence check
  -- Stops scanning account_operations after first match per type
  WHERE EXISTS (
    SELECT 1 FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id AND ao.op_type_id = hot.id
      AND ao.operation_id < __upper_operation_id
  );

END
$$;

RESET ROLE;
