SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_op_types(
    _operation_name TEXT
)
RETURNS SETOF hafah_backend.op_types 
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY SELECT
    id::INT, split_part(name, '::', 3), is_virtual
  FROM hafd.operation_types
  WHERE ((_operation_name IS NULL) OR (name LIKE _operation_name))
  ORDER BY id ASC;
END
$$;

RESET ROLE;
