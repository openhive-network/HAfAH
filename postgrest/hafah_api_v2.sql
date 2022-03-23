/*
API for pure API calls:
curl -X POST http://localhost:3000/rpc/get_transaction \
	-H 'Content-Type: application/json' \
	-H 'Content-Profile: hafah_api_v2' \
	-d  '{"_id": "390464f5178defc780b5d1a97cb308edeb27f983", "_include_reversible": true}'
*/
DROP SCHEMA IF EXISTS hafah_api_v2 CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api_v2;

CREATE FUNCTION hafah_api_v2.get_ops_in_block(_block_num INT = 0, _only_virtual BOOLEAN = FALSE, _include_reversible BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_python.get_ops_in_block_json(_block_num, _only_virtual, _include_reversible, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v2.enum_virtual_ops(_block_range_begin INT, _block_range_end INT, _operation_begin BIGINT = 0, _limit INT = 150000, _filter NUMERIC = NULL, _include_reversible BOOLEAN = FALSE, _group_by_block BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_python.enum_virtual_ops_json(_filter, _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible, _group_by_block);
END
$$
;

CREATE FUNCTION hafah_api_v2.get_transaction(_id TEXT, _include_reversible BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_python.get_transaction_json(_id::BYTEA, _include_reversible, hafah_backend.parse_is_legacy_style());
END
$$
;

CREATE FUNCTION hafah_api_v2.get_account_history(_account VARCHAR, _start BIGINT = -1, _limit BIGINT = 1000, _operation_filter_low NUMERIC = 0, _operation_filter_high NUMERIC = 0, _include_reversible BOOLEAN = FALSE)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN hafah_python.ah_get_account_history_json(
    _operation_filter_low, _operation_filter_high,
    _account,
    hafah_backend.parse_acc_hist_start(_start),
    hafah_backend.parse_acc_hist_limit(_limit),
    _include_reversible,
    hafah_backend.parse_is_legacy_style()
  );
END
$$
;