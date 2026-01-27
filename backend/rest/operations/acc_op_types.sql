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
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_acc_op_types(
    _account_id INT
)
RETURNS INT[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN array_agg(hot.id ORDER BY hot.id)
  FROM hafd.operation_types hot
  WHERE EXISTS (
    SELECT 1 FROM hive.account_operations_view aov
    WHERE aov.account_id = _account_id AND aov.op_type_id = hot.id
  );

END
$$;

RESET ROLE;
