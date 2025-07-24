SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_operation_types(
    _operations TEXT,
    _include_virtual BOOLEAN
)
RETURNS INT []-- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS
$$
DECLARE
  _non_virtual_ops INT[];
  _all_ops INT[];
  _operation_ids INT[] := (SELECT string_to_array(_operations, ',')::INT[]);
BEGIN
  IF _include_virtual IS TRUE THEN

    _all_ops := (
      SELECT array_agg(id)::INT[]
      FROM hafd.operation_types
    );

    PERFORM hafah_backend.validate_operation_types(_operation_ids, _all_ops);

    RETURN _operation_ids;
  END IF;
  
  _non_virtual_ops := (
    SELECT array_agg(id)::INT[]
    FROM hafd.operation_types
    WHERE is_virtual = FALSE 
  );

  IF _operation_ids IS NULL THEN
    RETURN _non_virtual_ops;
  END IF;

  PERFORM hafah_backend.validate_operation_types(_operation_ids, _non_virtual_ops);

  RETURN _operation_ids;
END
$$;

RESET ROLE;
