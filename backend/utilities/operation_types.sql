SET ROLE hafah_owner;

/*
 * operation_types.sql: Operation type parsing and retrieval.
 *
 * Functions:
 *   - hafah_backend.get_operation_types() - Parse and validate operation type IDs
 */

/*
 * ===================================================================================
 * get_operation_types
 * ===================================================================================
 * PURPOSE: Parses a comma-separated string of operation type IDs and validates them
 *          against allowed operations based on whether virtual operations are included.
 *
 * PARAMETERS:
 *   _operations      - Comma-separated string of operation type IDs
 *   _include_virtual - Whether to include virtual operations in allowed set
 *
 * RETURNS: INT[] - array of validated operation type IDs
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_operation_types(
    _operations         TEXT,
    _include_virtual    BOOLEAN
)
RETURNS INT[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS $$
DECLARE
  __non_virtual_ops INT[];
  __all_ops INT[];
  __operation_ids INT[] := (SELECT string_to_array(_operations, ',')::INT[]);
BEGIN
  IF _include_virtual IS TRUE THEN
    __all_ops := (
      SELECT array_agg(id)::INT[]
      FROM hafd.operation_types
    );

    PERFORM hafah_backend.validate_operation_types(__operation_ids, __all_ops);

    RETURN __operation_ids;
  END IF;

  __non_virtual_ops := (
    SELECT array_agg(id)::INT[]
    FROM hafd.operation_types
    WHERE is_virtual = FALSE
  );

  PERFORM hafah_backend.validate_operation_types(__operation_ids, __non_virtual_ops);

  RETURN __operation_ids;
END
$$;

RESET ROLE;
