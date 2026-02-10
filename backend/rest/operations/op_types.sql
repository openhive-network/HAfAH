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
 *
 * DATA SOURCES:
 *   - hafd.operation_types: Master list of all Hive operation types
 *
 * NOTES:
 *   - Operation names stored as fully-qualified C++ names (e.g., "hive::protocol::vote_operation")
 *   - split_part extracts user-friendly name ("vote_operation")
 *   - is_virtual distinguishes blockchain-generated ops from user transactions
 *   - Virtual ops include: rewards, vesting, interest, witness scheduling
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
    id,
    -- Name parsing: Extract operation name from C++ fully-qualified name
    -- "hive::protocol::vote_operation" -> "vote_operation"
    split_part(name, '::', 3),
    -- Virtual flag: TRUE for blockchain-generated operations
    is_virtual
  FROM hafd.operation_types
  -- LIKE filter: Supports wildcards (e.g., "%vote%" matches all vote-related ops)
  WHERE ((_operation_name IS NULL) OR (name LIKE _operation_name))
  ORDER BY id ASC;
END
$$;

RESET ROLE;
