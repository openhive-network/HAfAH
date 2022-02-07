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

CREATE OR REPLACE FUNCTION hafah_api.set_operation_id(_operation_id BIGINT, __fill_operation_id BOOLEAN)
RETURNS VARCHAR
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN __fill_operation_id IS TRUE THEN
    (SELECT CASE WHEN _operation_id >= 4294967295 THEN
      '"operation_id": "' || _operation_id || '" ' 
    ELSE
      '"operation_id": ' || _operation_id || ' '
    END)
  ELSE 
    '"operation_id": 0'
  END;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_reversible BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __fill_operation_id BOOLEAN = FALSE;
  __is_old_schema BOOLEAN = FALSE;
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
              (SELECT * FROM hafah_api.set_operation_id(_operation_id, __fill_operation_id)) ||
              '}'
            FROM hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible, __is_old_schema)
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
BEGIN
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

CREATE OR REPLACE FUNCTION hafah_api.get_account_history(_account VARCHAR, _start BIGINT = -1, _limit INT = 1000, _operation_filter_low INT = 0, _operation_filter_high INT = 0, _include_reversible BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
 __filter INT = ( _operation_filter_high << 64 ) | _operation_filter_low;
 __is_old_schema BOOLEAN = FALSE;
BEGIN
  _start = (SELECT CASE WHEN _start >= 0 THEN _start ELSE "9223372036854775807"::BIGINT END);

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
            FROM hafah_python.ah_get_account_history((SELECT * FROM hafah_api.translate_filter(__filter, 'get_account_history')), _account, _start, _limit, _include_reversible, __is_old_schema)
          )
          SELECT history FROM cte
        ) obj
      WHERE history IS NOT NULL
      ) to_arr
    ) is_null
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.get_transaction(_id TEXT,  _include_reversible BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
 __is_old_schema BOOLEAN = FALSE;
BEGIN
  RETURN obj::JSON FROM (
    SELECT CASE WHEN obj IS NULL THEN
      '{
      "block_num": null,
      "expiration": null,
      "extensions": [],
      "operations": [],
      "ref_block_num": null,
      "ref_block_prefix": null,
      "signatures": [],
      "transaction_id": "' || _id || '", ' || '
      "transaction_num": null
      }'
    ELSE
      obj
    END
    FROM (
      SELECT
        '{' ||
        '"ref_block_num": ' || _ref_block_num || ', ' ||
        '"ref_block_prefix": ' || _ref_block_prefix || ', ' ||
        '"expiration": "' || _expiration || '", ' ||
        '"operations": ' ||
        (
          SELECT json_agg(_value) FROM (
            SELECT _value::JSON FROM hafah_python.get_ops_in_transaction(_block_num, _trx_in_block, __is_old_schema)
          ) f_call
        ) || ', ' ||
        '"extensions": [], ' ||
        '"signatures": ' ||
        (
          SELECT CASE WHEN _multisig_number >= 1 THEN
            array_to_json(ARRAY(
              SELECT _signature
              UNION ALL
              SELECT * FROM hafah_python.get_multi_signatures_in_transaction(_id::BYTEA)
            ))::TEXT
          ELSE
            '["' || _signature || '"]'
          END
        )
        || ', ' ||
        '"transaction_id": "' || _id || '", ' ||
        '"block_num": ' || _block_num || ', ' ||
        '"transaction_num": ' || _trx_in_block || ' ' ||
        '}'::TEXT AS obj
      FROM hafah_python.get_transaction(_id::BYTEA, _include_reversible)
    ) is_null
  ) to_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.group_by_block(ops JSON, block_n_arr INT[], __irreversible_block INT)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN json_agg(ops_by_block::JSON)
  FROM (
    SELECT ops_by_block FROM (
      WITH cte AS (
        SELECT
          NULL::TEXT AS ops_by_block
        UNION ALL
        SELECT
          '{' ||
          '"block": ' || block_n || ', ' ||
          '"irreversible": ' ||
          (SELECT CASE WHEN block_n <= __irreversible_block IS TRUE THEN true ELSE false END) || ', ' ||
          '"ops": ' ||
          (SELECT json_agg(ops_elements) FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (SELECT ops_elements->>'block')::INT = block_n)
          || ', ' ||
          '"timestamp": "' || 
          (SELECT ops_elements->>'timestamp' FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (SELECT ops_elements->>'block')::INT = block_n LIMIT 1)
          || '" ' ||
          '}'
        FROM unnest(block_n_arr) AS block_n
      )
      SELECT ops_by_block FROM cte
    ) obj
  WHERE ops_by_block IS NOT NULL
  ) result;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.raise_exception(TEXT)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE EXCEPTION '%', $1;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.do_pagination(_block_range_end INT, _limit INT, ops_json JSONB, _fill_operation_id BOOLEAN, _group_by_block BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __len INT;
BEGIN
  SELECT CASE WHEN _group_by_block IS TRUE THEN jsonb_array_length(ops_json->'ops_by_block') ELSE jsonb_array_length(ops_json->'ops') END INTO __len;

  DROP TABLE IF EXISTS result;

  IF __len > 0 AND __len = _limit THEN
    CREATE TEMP TABLE result AS SELECT
      (SELECT CASE WHEN o.block_num IS NULL THEN 0 ELSE
        (SELECT CASE WHEN o.block_num >= _block_range_end THEN 0 ELSE o.block_num END)
      END) AS next_block_range_begin,
      (SELECT CASE WHEN o.id IS NULL THEN 0 ELSE
      -- TODO: (SELECT hafah_api.set_operation_id(o.id, _fill_operation_id))
      (SELECT o.id)
      END) AS next_operation_begin
    FROM
      hive.operations o
    JOIN hive.operation_types ot ON o.op_type_id = ot.id
    WHERE
      CASE WHEN _group_by_block IS TRUE THEN
        ot.is_virtual = TRUE AND
        o.block_num >= (ops_json->'ops_by_block'->-1->'block')::INT AND
        o.id > (ops_json->'ops_by_block'->-1->'ops'->-1->'operation_id')::BIGINT
      ELSE
        ot.is_virtual = TRUE AND
        o.block_num >= (ops_json->'ops'->-1->>'block')::INT AND
        o.id > (ops_json->'ops'->-1->>'operation_id')::BIGINT
      END
    ORDER BY o.block_num, o.id 
    LIMIT 1;
  ELSE
    CREATE TEMP TABLE result AS SELECT
      _block_range_end AS next_block_range_begin,
      0 AS next_operation_begin;
  END IF;

  ops_json = (
    SELECT jsonb_set(ops_json,
    '{next_block_range_begin}',
    to_jsonb((SELECT next_block_range_begin FROM result)))
  );

  ops_json = (
    SELECT jsonb_set(ops_json,
    '{next_operation_begin}',
    to_jsonb((SELECT next_operation_begin FROM result)))
  );

  RETURN ops_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_api.enum_virtual_ops(_block_range_begin INT, _block_range_end INT, _operation_begin BIGINT = 0, _limit INT = 2147483646, _filter INT = NULL, _include_reversible BOOLEAN = FALSE, _group_by_block BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __fill_operation_id BOOLEAN = TRUE;
  __virtual_op_id_offset INT = (SELECT MIN(id) FROM hive.operation_types WHERE is_virtual = True);
  __irreversible_block INT;
BEGIN
  IF _block_range_begin > _block_range_end THEN
    SELECT raise_exception('block range must be upward');
  END IF;

  IF _block_range_end - _block_range_begin > 2000 THEN
    SELECT raise_exception('block range distance must be less than or equal to 2000');
  END IF;

  IF _group_by_block IS TRUE THEN
    SELECT hive.app_get_irreversible_block() INTO __irreversible_block;
  END IF;

  RETURN
    (SELECT hafah_api.do_pagination(_block_range_end, _limit, ops_json, __fill_operation_id, _group_by_block))
  FROM (
    SELECT
      jsonb_build_object(
        'ops', CASE WHEN _group_by_block IS TRUE OR ops IS NULL THEN '[]'::JSON ELSE ops END,
        'ops_by_block', CASE WHEN _group_by_block IS FALSE OR ops IS NULL THEN '[]'::JSON ELSE (SELECT hafah_api.group_by_block(ops, block_n_arr, __irreversible_block)) END,
        'next_block_range_begin', 0,
        'next_operation_begin', 0
      ) AS ops_json
    FROM (
      SELECT
        json_agg(ops::JSONB) AS ops,
        array_agg(DISTINCT block_n) AS block_n_arr
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
              (SELECT CASE WHEN _operation_id IS NULL THEN
                hafah_api.raise_exception('_operation_id cannot be NULL')
              ELSE
                hafah_api.set_operation_id(_operation_id, __fill_operation_id)
              END) ||
              '}',
              _block
            FROM hafah_python.enum_virtual_ops((SELECT * FROM hafah_api.translate_filter(_filter, 'enum_virtual_ops', __virtual_op_id_offset)), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
          )
          SELECT ops, block_n FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) group_b
  ) result;
END
$$
;

/*
DEVELOP BRANCH VERSION (OLD)

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

RETURN to_jsonb(result) FROM (
  SELECT
    CASE WHEN _group_by_block IS TRUE OR ops IS NULL THEN '[]'::JSON ELSE ops END AS ops,
    next_block_range_begin,
    next_operation_begin,
    CASE WHEN _group_by_block IS FALSE OR ops IS NULL THEN '[]'::JSON ELSE (SELECT * FROM hafah_api.group_by_block(ops, block_n_arr, __irreversible_block)) END AS ops_by_block
  FROM (
    SELECT
      ops->-1->'block' AS next_block_range_begin,
      CASE WHEN _block_range_end < (SELECT ops->-1->>'block')::INT THEN ops->-1->'operation_id' ELSE '0'::JSON END AS next_operation_begin,
      hafah_api.remove_last_op(ops, n - 1)::JSON AS ops,
      ops,
      block_n_arr
    FROM (
      SELECT
        json_agg(ops::JSON) AS ops,
        array_agg(DISTINCT block_n) AS block_n_arr,
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
              (SELECT * FROM hafah_api.set_operation_id(_operation_id, __fill_operation_id)) ||
              '}',
              _block
            FROM hafah_python.enum_virtual_ops((SELECT * FROM hafah_api.translate_filter(_filter, 'enum_virtual_ops', __virtual_op_id_offset)), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
          )
          SELECT ops, block_n FROM cte
        ) obj
      WHERE ops IS NOT NULL
      ) to_arr
    ) pagination
  ) next_begin
) result;
*/