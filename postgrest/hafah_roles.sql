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
