SET ROLE hafah_owner;

/*
 * helpers.sql: Miscellaneous REST API helper functions.
 *
 * Functions:
 *   - hafah_backend.is_block_missing() - Check if block parameter is missing
 *   - hafah_backend.is_path_filter_not_empty() - Check if path filter has values
 *   - hafah_backend.get_group_type() - Convert operation group type to boolean
 */

/*
 * ===================================================================================
 * is_block_missing
 * ===================================================================================
 * PURPOSE: Raises an exception if the block number parameter is NULL.
 *
 * PARAMETERS:
 *   _block_num - Block number to check
 *   _name      - Parameter name for error message (default: 'block-num')
 *
 * RETURNS: VOID (raises exception if block_num is NULL)
 */
CREATE OR REPLACE FUNCTION hafah_backend.is_block_missing(
    _block_num    INT,
    _name         TEXT DEFAULT 'block-num'
)
RETURNS VOID
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  IF _block_num IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg(_name);
  END IF;
END
$$;

/*
 * ===================================================================================
 * is_path_filter_not_empty
 * ===================================================================================
 * PURPOSE: Checks if a path filter array has any values.
 *
 * PARAMETERS:
 *   _path_filter - Array of path filter values
 *
 * RETURNS: BOOLEAN - TRUE if filter has values, FALSE otherwise
 */
CREATE OR REPLACE FUNCTION hafah_backend.is_path_filter_not_empty(
    _path_filter    TEXT[]
)
RETURNS BOOLEAN
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (_path_filter IS NOT NULL AND _path_filter != '{}');
END
$$;

/*
 * ===================================================================================
 * get_group_type
 * ===================================================================================
 * PURPOSE: Converts operation group type enum to boolean for filtering virtual operations.
 *          'real' -> FALSE (non-virtual), 'virtual' -> TRUE, anything else -> NULL (all)
 *
 * PARAMETERS:
 *   _group_type - Operation group type enum value
 *
 * RETURNS: BOOLEAN - FALSE for real, TRUE for virtual, NULL for all
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_group_type(
    _group_type    hafah_backend.operation_group_types -- noqa: LT01, CP05
)
RETURNS BOOLEAN
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (
    CASE
      WHEN _group_type = 'real' THEN
        FALSE
      WHEN _group_type = 'virtual' THEN
        TRUE
      ELSE
        NULL
    END
  );
END
$$;

RESET ROLE;
