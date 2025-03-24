SET ROLE hafah_owner;

-- used in account page endpoint
CREATE OR REPLACE FUNCTION hafah_backend.get_account_operations_count(
    _operations INT [],
    _account_id INT,
    _from INT,
    _to INT
)
RETURNS BIGINT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET from_collapse_limit = 16
SET join_collapse_limit = 16
SET enable_hashjoin = OFF
SET JIT = OFF
AS
$$
BEGIN
  IF _operations IS NULL THEN
    RETURN _to - _from + 1;
  END IF;

  RETURN (
  -- using hive_account_operations_uq2, we are forcing planner to use this index on (account_id,operation_id), it achives better performance results
    SELECT COUNT(*)
    FROM hive.account_operations_view aov
    WHERE aov.account_id = _account_id
    AND aov.op_type_id = ANY(_operations)
    AND aov.account_op_seq_no >= _from
    AND aov.account_op_seq_no <= _to
  );

END
$$;

RESET ROLE;
