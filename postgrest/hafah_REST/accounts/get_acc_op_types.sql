SET ROLE hafah_owner;

/** openapi:paths
/accounts/{account-name}/operation-types:
  get:
    tags:
      - Accounts
    summary: Lists operation types
    description: |
      Lists all types of operations that the account has performed since its creation

      SQL example
      * `SELECT * FROM hafah_endpoints.get_acc_op_types(''blocktrades'');`

      REST call example
      * `GET ''https://%1$s/hafah/accounts/blocktrades/operations/types''`
    operationId: hafah_endpoints.get_acc_op_types
    parameters:
      - in: path
        name: account-name
        required: true
        schema:
          type: string
        description: Name of the account
    responses:
      '200':
        description: |
          Operation type list

          * Returns `JSONB`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSONB
            example:
              - [
                  0,
                  1,
                  2,
                  3,
                  4,
                  5,
                  6,
                  7,
                  10,
                  11,
                  12,
                  13,
                  14,
                  15,
                  18,
                  20,
                  51,
                  52,
                  53,
                  55,
                  56,
                  57,
                  61,
                  64,
                  72,
                  77,
                  78,
                  79,
                  80,
                  85,
                  86
                ]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_acc_op_types;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_acc_op_types(
    "account-name" TEXT
)
RETURNS JSONB 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __account_id INT = (SELECT av.id FROM hive.accounts_view av WHERE av.name = "account-name");
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN (
    WITH op_types_cte AS 
    (
      SELECT id
      FROM hive.operation_types hot
      WHERE (
        SELECT EXISTS (
          SELECT 1 FROM hive.account_operations_view aov WHERE aov.account_id = __account_id AND aov.op_type_id = hot.id))
    )

    SELECT jsonb_agg(to_jsonb(cte.id::INT))
    FROM op_types_cte cte
  );
END
$$;

RESET ROLE;
