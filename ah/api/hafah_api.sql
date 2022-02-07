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

CREATE OR REPLACE FUNCTION hafah_api.convert_operation_id(_operation_id BIGINT, __include_op_id BOOLEAN)
RETURNS VARCHAR
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN __include_op_id IS TRUE::BOOLEAN THEN
    '"operation_id": "' || (9223372036854775808 + _operation_id)::VARCHAR || '" '
  ELSE 
    '"operation_id": 0'
  END;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __include_op_id BOOLEAN = FALSE;
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT CASE WHEN ops IS NULL THEN
      '[]'::JSON
    ELSE
      ops
    END AS ops
    FROM (
      SELECT json_agg(ops::JSON) AS ops FROM (
        SELECT ops FROM (
          WITH cte AS (
            SELECT
                NULL::TEXT AS ops
            UNION ALL
            SELECT
              '{' ||
              '"trx_id": "' || _trx_id || '", ' ||
              '"block": ' || _block_num || ', ' ||
              '"trx_in_block": ' || _trx_in_block || ', ' ||
              '"op_in_trx": ' || _op_in_trx || ', ' ||
              '"virtual_op": ' || _virtual_op || ', ' ||
              '"timestamp": "' || _timestamp || '", ' ||
              '"op": ' || _value || ', ' ||
              (SELECT * FROM hafah_api.convert_operation_id(_operation_id, __include_op_id)) ||
              '}'
            FROM hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible)
          )
          SELECT ops FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) is_null
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.translate_filter(_filter INT, _endpoint_name TEXT, _transform INT = 0)
RETURNS INT[]
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __operation_filter_high INT = 0;
  __operation_filter_low INT =  0;
BEGIN
  IF _endpoint_name = 'get_account_history' THEN
    _filter = ( __operation_filter_high << 64 ) | __operation_filter_low;
  END IF;

  IF _filter != 0 THEN
    RETURN array_agg(val + _transform) FROM (
      WITH RECURSIVE cte(i, val) AS (
        VALUES(-1, 0)
      UNION ALL
        SELECT
          i + 1,
          CASE WHEN _filter & (1 << i + 1) != 0 THEN i + 1 END          
        FROM cte 
        WHERE i < 127 
      )
      SELECT i, val FROM cte WHERE val IS NOT NULL AND i != -1 AND val < 10
    ) ints;
  ELSE
    RETURN NULL;
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_account_history(_filter INT, _account VARCHAR, _start BIGINT, _limit INT, _include_reversible BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN to_jsonb(result) FROM (
    SELECT CASE WHEN history IS NULL THEN
      '[]'::JSON
    ELSE
      history
    END AS history
    FROM (
      SELECT json_agg(history::JSON) AS history FROM (
        SELECT history FROM (
          WITH cte AS (
            SELECT
              NULL::TEXT AS history
            UNION ALL
            SELECT
              '[' || _operation_id || ',' ||
              '{' ||
              '"trx_id": "' || _trx_id || '", ' ||
              '"block": ' || _block || ', ' ||
              '"trx_in_block": ' || _trx_in_block || ', ' ||
              '"op_in_trx": ' || _op_in_trx || ', ' ||
              '"virtual_op": ' || _virtual_op || ', ' ||
              '"timestamp": "' || _timestamp || '", ' ||
              '"op": ' || _value || ', ' ||
              '"operation_id": 0' || ' ' ||
              '}' ||
              ']'
            FROM hafah_python.ah_get_account_history((SELECT * FROM hafah_api.translate_filter(_filter, 'get_account_history')), _account, _start, _limit, _include_reversible)
          )
          SELECT history FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) is_null
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
    FROM hafah_python.get_transaction(_trx_hash::BYTEA, _include_reversible)
  ) to_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.remove_last_op(pos JSON, _n INT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    json_agg(value)
  FROM
    json_array_elements(pos)
  WITH ordinality 
    WHERE ordinality 
    BETWEEN 0 AND _n;
END
$$
;

-- TODO: create group_by_block()
CREATE OR REPLACE FUNCTION hafah_api.group_by_block(ops JSON, block_n_arr INT[], __irreversible_block INT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN ops;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.enum_virtual_ops(_filter INT, _block_range_begin INT, _block_range_end INT, _operation_begin BIGINT, _limit INT,  _include_reversible BOOLEAN, _group_by_block BOOLEAN)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __include_op_id BOOLEAN = TRUE;
  __upper_block_limit INT = (SELECT * FROM hive.app_get_irreversible_block());
  __virtual_op_id_offset INT = (SELECT MAX(id) AS id FROM hive.operation_types WHERE is_virtual = False);
  __irreversible_block INT;
BEGIN
  IF _group_by_block IS TRUE THEN
    SELECT hive.app_get_irreversible_block() INTO __irreversible_block;
  END IF;

  RETURN to_jsonb(result) FROM (
    /*
    SELECT CASE WHEN ops IS NULL THEN
      '[]'::JSON
    ELSE
      ops
    END AS ops
    FROM (
    */
    SELECT
      CASE WHEN _group_by_block IS TRUE THEN '[]'::JSON ELSE ops END AS ops,
      next_block_range_begin,
      next_operation_begin,
      CASE WHEN _group_by_block IS FALSE THEN '[]'::JSON ELSE ops END AS ops_by_block
    FROM (
      SELECT
        ops->-1->'block' AS next_block_range_begin,
        ops->-1->'operation_id' AS next_operation_begin,
        hafah_api.remove_last_op(
          (SELECT CASE WHEN _group_by_block IS TRUE THEN hafah_api.group_by_block(ops, (SELECT DISTINCT block_n_arr), __irreversible_block) ELSE ops END),
        n - 1)::JSON AS ops
      FROM (
        SELECT
          json_agg(ops::JSON) AS ops,
          array_agg(block_n) AS block_n_arr,
          count(ops)::INT AS n
        FROM (
          SELECT ops, block_n FROM (
            WITH cte AS (
              SELECT
                NULL::TEXT AS ops,
                NULL::INT AS block_n
              UNION ALL
              SELECT
                -- TODO: create body for api_operation, duplicate in get_ops_in_block()
                '{' ||
                '"trx_id": "' || _trx_id || '", ' ||
                '"block": ' || _block || ', ' ||
                '"trx_in_block": ' || _trx_in_block || ', ' ||
                '"op_in_trx": ' || _op_in_trx || ', ' ||
                '"virtual_op": ' || _virtual_op || ', ' ||
                '"timestamp": "' || _timestamp || '", ' ||
                '"op": ' || _value || ', ' ||
                (SELECT * FROM hafah_api.convert_operation_id(_operation_id, __include_op_id)) ||
                '}',
                _block
              FROM hafah_python.enum_virtual_ops((SELECT * FROM hafah_api.translate_filter(_filter, 'enum_virtual_ops', __virtual_op_id_offset)), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
            )
            SELECT ops, block_n FROM cte
          ) obj
        WHERE ops IS NOT NULL
        ) to_arr
      ) pagination
    ) to_json
    --) is_null
  ) result;
END
$$
;