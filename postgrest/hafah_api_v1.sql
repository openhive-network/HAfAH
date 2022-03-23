/*
API for new style calls:
curl -X POST http://localhost:3000/rpc/get_transaction \
	-H 'Content-Type: application/json' \
	-H 'Content-Profile: hafah_api_v1' \
	-d  '{"id": "390464f5178defc780b5d1a97cb308edeb27f983", "include_reversible": true}'
*/
DROP SCHEMA IF EXISTS hafah_api_v1 CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api_v1;

CREATE FUNCTION hafah_api_v1.get_ops_in_block(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.get_ops_in_block($1, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.enum_virtual_ops(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.enum_virtual_ops($1, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.get_transaction(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.get_transaction($1, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.get_account_history(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_endpoints.get_account_history($1, hafah_backend.parse_is_legacy_style());
END
$$
;