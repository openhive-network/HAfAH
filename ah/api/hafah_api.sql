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

CREATE OR REPLACE FUNCTION hafah_api.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_op_id BOOLEAN, _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    -- TODO: when NULL return empty list
    SELECT json_agg(ops::JSON) AS ops FROM (
      SELECT ops FROM (
        WITH cte AS (
          SELECT
            ''::TEXT AS ops
          UNION ALL
          SELECT
            '{' ||
            '"block": ' || _block_num || ', ' ||
            '"op": ' || _value || ', ' ||
            '"op_in_trx": ' || _op_in_trx || ', ' ||
            -- TODO: Change _operation_id expression when _include_reversible is false
            '"operation_id": ' || CASE WHEN _include_op_id IS TRUE THEN _operation_id ELSE 0 END || ', ' ||
            '"timestamp": "' || _timestamp || '", ' ||
            '"trx_id": "' || _trx_id || '", ' ||
            '"trx_in_block": ' || _trx_in_block || ', ' ||
            '"virtual_op": ' || _virtual_op || '' ||
            '}'
          FROM (
            SELECT
              _value,
              _op_in_trx,
              _operation_id,
              _timestamp,
              _trx_id,
              _trx_in_block,
              _virtual_op
            FROM
              hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible)
          ) f_call
        )
        SELECT row_number() OVER () AS id, ops FROM cte
      ) obj
    WHERE id > 1
    ) to_arr
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

CREATE OR REPLACE FUNCTION hafah_api.get_transaction(_trx_hash TEXT,  _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN obj::JSON FROM (
    SELECT
      '{' ||
      '"ref_block_num": ' || _ref_block_num || ', ' ||
      '"ref_block_prefix": ' || _ref_block_prefix || ', ' ||
      '"expiration": "' || _expiration || '", ' ||
      '"operations": ' ||
      (
        SELECT json_agg(_value) FROM (
          SELECT _value::JSON FROM hafah_python.get_ops_in_transaction(_block_num, _trx_in_block)
        ) f_call
      ) || ', ' ||
      '"extensions": [], ' ||
      '"signatures": ' ||
      (
        SELECT CASE WHEN _multisig_number >= 1 THEN
          '[]' -- TODO: return array for multiple signature transaction
        ELSE
          '["' || _signature || '"]'
        END
      )
      || ', ' ||
      '"transaction_id": "' || _trx_hash || '", ' ||
      '"block_num": ' || _block_num || ', ' ||
      '"transaction_num": ' || _trx_in_block || ' ' ||
      '}'::TEXT AS obj
    FROM (
      SELECT * FROM hafah_python.get_transaction(_trx_hash::BYTEA, _include_reversible)
    ) transaction_basic_info
  ) to_json;
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