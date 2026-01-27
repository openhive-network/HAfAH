SET ROLE hafah_owner;

/*
 * operation_body_filter.sql: Operation body filtering functions.
 *
 * Types:
 *   - hafah_backend.operation_body_filter_result - Return type for operation_body_filter
 *
 * Functions:
 *   - hafah_backend.operation_body_filter() - Filter/truncate operation bodies
 */

-- ===================================================================================
-- TYPES
-- ===================================================================================

DROP TYPE IF EXISTS hafah_backend.operation_body_filter_result CASCADE; -- noqa: LT01
CREATE TYPE hafah_backend.operation_body_filter_result AS (
    body           JSONB,
    id             TEXT,
    is_modified    BOOLEAN
);

-- ===================================================================================
-- FUNCTIONS
-- ===================================================================================

/*
 * ===================================================================================
 * operation_body_filter
 * ===================================================================================
 * PURPOSE: Filters operation bodies that exceed a specified length limit.
 *          Used in body-returning functions to limit too-long operation bodies.
 *          Too long operations are replaced by a placeholder with metadata,
 *          allowing frontend to open the full operation in another page.
 *
 * PARAMETERS:
 *   _body       - Operation body as JSONB
 *   _op_id      - Operation ID
 *   _body_limit - Maximum body length (default: max INT value)
 *
 * RETURNS: hafah_backend.operation_body_filter_result - filtered body, id, and modified flag
 */
CREATE OR REPLACE FUNCTION hafah_backend.operation_body_filter(
    _body          JSONB,
    _op_id         BIGINT,
    _body_limit    INT DEFAULT 2147483647
)
RETURNS hafah_backend.operation_body_filter_result -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __result hafah_backend.operation_body_filter_result := (_body, _op_id, FALSE);
BEGIN
  IF length(_body::TEXT) > _body_limit THEN
    __result.body := jsonb_build_object(
      'type', 'body_placeholder_operation',
      'value', jsonb_build_object(
        'org-op-id', _op_id::TEXT,
        'org-operation_type', _body->>'type',
        'truncated_body', 'body truncated up to specified limit just for presentation purposes'
      )
    );
    __result.is_modified := TRUE;
  END IF;

  RETURN __result;
END
$$;

RESET ROLE;
