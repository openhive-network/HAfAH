ALTER SYSTEM SET session_preload_libraries TO 'libquery_supervisor.so';
ALTER SYSTEM SET query_supervisor.limited_users TO 'alice';
SELECT pg_reload_conf();