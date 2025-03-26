SET ROLE hafah_owner;

-- used in account page endpoint
CREATE OR REPLACE FUNCTION hafah_backend.get_acc_op_types(
    _account_id INT
)
RETURNS INT[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN array_agg(hot.id) 
  FROM hafd.operation_types hot
  WHERE EXISTS (
    SELECT 1 FROM hive.account_operations_view aov 
    WHERE aov.account_id = _account_id AND aov.op_type_id = hot.id
  ORDER BY hot.id
  );

END
$$;

RESET ROLE;
