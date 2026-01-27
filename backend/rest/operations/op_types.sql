SET ROLE hafah_owner;

/*
 * op_types.sql: REST API backend for operation types retrieval.
 *
 * Called by: hafah_endpoints.get_operation_types() in endpoints/operation_types/get_operation_types.sql
 *
 * REST Endpoint: GET /operation-types
 */

/*
 * ===================================================================================
 * get_op_types
 * ===================================================================================
 * PURPOSE: Retrieve list of all operation types or filter by name pattern.
 *
 * PARAMETERS:
 *   _operation_name - Optional LIKE pattern to filter operation names (NULL for all)
 *
 * RETURNS: Set of operation types with ID, name, and virtual flag
 */
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
