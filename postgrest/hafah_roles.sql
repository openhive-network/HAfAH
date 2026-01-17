GRANT USAGE, CREATE ON SCHEMA hafah_helper TO hafah_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hafah_helper TO hafah_user;

GRANT USAGE ON SCHEMA hafah_endpoints TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_endpoints TO hafah_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hafah_backend TO hafah_user;
GRANT USAGE ON SCHEMA hafah_backend TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_backend TO hafah_user;

GRANT USAGE ON SCHEMA hafah_python TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_python TO hafah_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hafah_python TO hafah_user;

--- Definition of this function must be at the end of setup
--- (after all permission grants, so wait_for_setup_completed.sh
---  doesn't signal ready before hafah_user has access)
CREATE OR REPLACE FUNCTION hafah_python.is_setup_completed()
RETURNS BOOLEAN
IMMUTABLE
LANGUAGE PLPGSQL
AS
$$
BEGIN
  RETURN TRUE;
END
$$
;
