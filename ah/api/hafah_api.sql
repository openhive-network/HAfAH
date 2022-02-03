DROP SCHEMA IF EXISTS hafah_api CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_api;

CREATE OR REPLACE PROCEDURE hafah_api.create_api_user()
LANGUAGE 'plpgsql'
AS $$
BEGIN
  --recreate role for reading data
  DROP OWNED BY hived;
  DROP ROLE IF EXISTS hived;
  CREATE ROLE hived;

  GRANT USAGE ON SCHEMA hafah_api TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_api TO hived;

  GRANT USAGE ON SCHEMA hafah_python TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hafah_python TO hived;

  GRANT USAGE ON SCHEMA hive TO hived;
  GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hived;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hived;

  -- recreate role for connecting to db
  DROP ROLE IF EXISTS haf_admin;
  CREATE ROLE haf_admin NOINHERIT LOGIN PASSWORD 'haf_admin';

  -- add ability for admin to switch to hived role
  GRANT hived TO haf_admin;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT
      json_agg(_trx_in_block) AS _trx_in_block,
      json_agg(_op_in_trx) AS _op_in_trx,
      json_agg(_virtual_op) AS _virtual_op,
      json_agg(_timestamp) AS _timestamp,
      json_agg(_value) AS _value,
      json_agg(_operation_id) AS _operation_id
    FROM (
      SELECT * FROM hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible)
    ) obj
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_account_history(_filter INT[], _account VARCHAR, _start BIGINT, _limit INT, _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT
      json_agg(_trx_id) AS _trx_id,
      json_agg(_block) AS _block,
      json_agg(_trx_in_block) AS _trx_in_block,
      json_agg(_op_in_trx) AS _op_in_trx,
      json_agg(_virtual_op) AS _virtual_op,
      json_agg(_timestamp) AS _timestamp,
      json_agg(_value) AS _value,
      json_agg(_operation_id) AS _operation_id
    FROM (
      SELECT * FROM hafah_python.ah_get_account_history(_filter, _account, _start, _limit, _include_reversible)
    ) obj
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_transaction(_trx_hash BYTEA,  _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT
      json_agg(_ref_block_num) AS _ref_block_num,
      json_agg(_ref_block_prefix) AS _ref_block_prefix,
      json_agg(_expiration) AS _expiration,
      json_agg(_block_num) AS _block_num,
      json_agg(_trx_in_block) AS _trx_in_block,
      json_agg(_signature) AS _signature,
      json_agg(_multisig_number) AS _multisig_number
    FROM (
      SELECT * FROM hafah_python.get_transaction(_trx_hash, _include_reversible)
    ) obj
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.enum_virtual_ops(_filter INT[], _block_range_begin INT, _block_range_end INT, _operation_begin BIGINT, _limit INT,  _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT
      json_agg(_trx_id) AS _trx_id,
      json_agg(_trx_in_block) AS _trx_in_block,
      json_agg(_op_in_trx) AS _op_in_trx,
      json_agg(_virtual_op) AS _virtual_op,
      json_agg(_timestamp) AS _timestamp,
      json_agg(_value) AS _value,
      json_agg(_operation_id) AS _operation_id
    FROM (
      SELECT * FROM hafah_python.enum_virtual_ops(_filter, _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
    ) obj
  ) result;
END
$$
;