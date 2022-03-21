DROP SCHEMA IF EXISTS hafah_api_v1 CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api_v1;

CREATE FUNCTION hafah_api_v1.get_ops_in_block(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __params JSON = $1;
BEGIN
  RETURN hafah_endpoints.get_ops_in_block(__params, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.enum_virtual_ops(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __params JSON = $1;
BEGIN
  RETURN hafah_endpoints.enum_virtual_ops(__params, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.get_transaction(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __params JSON = $1;
BEGIN
  RETURN hafah_endpoints.get_transaction(__params, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v1.get_account_history(JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __params JSON = $1;
BEGIN
  RETURN hafah_endpoints.get_account_history(__params, hafah_backend.parse_is_legacy_style());
END
$$
;