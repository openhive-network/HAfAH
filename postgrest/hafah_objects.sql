/*
ah/api/hafah_objects.sql

Functions with method names queries hafah_python schema and converts result tables to json objects:
  - get_ops_in_block
  - enum_virtual_ops
  - get_transaction
  - get_account_history
*/

DROP SCHEMA IF EXISTS hafah_objects CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_objects;

CREATE OR REPLACE FUNCTION hafah_objects.set_operation_id(_operation_id BIGINT, _fill_operation_id BOOLEAN, _id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __operation_id JSON;
BEGIN
  IF _operation_id IS NULL THEN
    RETURN hafah_backend.raise_operation_id_exception(_id);
  END IF;

  IF _fill_operation_id IS TRUE THEN
    IF _operation_id >= 4294967295 THEN
      __operation_id = to_json(_operation_id::TEXT);
    ELSE
      __operation_id = to_json(_operation_id);
    END IF;
  ELSE 
    __operation_id = to_json(0);
  END IF;

  RETURN __operation_id;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_objects.build_api_operation(_trx_id TEXT, _block INT, _trx_in_block BIGINT, _op_in_trx BIGINT, _virtual_op BOOLEAN, _timestamp TEXT, _value TEXT, _operation_id BIGINT, _fill_operation_id BOOLEAN, _id JSON, _is_old_schema BOOLEAN = FALSE)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN
    '{' ||
    '"trx_id": "' || _trx_id || '", ' ||
    '"block": ' || _block || ', ' ||
    '"trx_in_block": ' || _trx_in_block || ', ' ||
    '"op_in_trx": ' || _op_in_trx || ', ' ||
    '"virtual_op": ' || _virtual_op || ', ' ||
    '"timestamp": "' || _timestamp || '", ' ||
    '"op": ' || _value ||
    CASE WHEN _is_old_schema IS TRUE THEN
      ''
    ELSE
      ', ' || '"operation_id": ' || hafah_objects.set_operation_id(_operation_id, _fill_operation_id, _id)
    END
    || '}';
END
$$
;

CREATE OR REPLACE FUNCTION hafah_objects.get_ops_in_block(_block_num INT, _only_virtual BOOLEAN, _include_reversible BOOLEAN, _fill_operation_id BOOLEAN, _is_old_schema BOOLEAN, _id JSON)
RETURNS TEXT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _is_old_schema IS TRUE THEN
    ops
  ELSE
    to_jsonb(result)
  END
  FROM (
    SELECT CASE WHEN ops IS NULL THEN
      '[]'::JSONB
    ELSE
      ops
    END AS ops
    FROM (
      SELECT jsonb_agg(ops::JSONB) AS ops FROM (
        SELECT ops FROM (
          WITH cte AS (
            SELECT
                NULL::TEXT AS ops
            UNION ALL
            SELECT hafah_objects.build_api_operation(_trx_id, _block_num, _trx_in_block, _op_in_trx, _virtual_op, _timestamp, _value, _operation_id, _fill_operation_id, _id, _is_old_schema)
            FROM hafah_python.get_ops_in_block(_block_num, _only_virtual, _include_reversible, _is_old_schema)
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

CREATE OR REPLACE FUNCTION hafah_objects.get_account_history(_filter NUMERIC, _account VARCHAR, _start BIGINT, _limit INT, _include_reversible BOOLEAN, _is_old_schema BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN CASE WHEN _is_old_schema IS TRUE THEN
    history
  ELSE
    to_json(result)
  END
  FROM (
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
              '"op": ' || _value ||
              CASE WHEN _is_old_schema IS TRUE THEN
                ''
              ELSE
                ', ' || '"operation_id": 0'
              END
              || '}' ||
              ']'
            FROM hafah_python.ah_get_account_history(hafah_backend.translate_filter(_filter), _account, _start, _limit, _include_reversible, _is_old_schema)
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

CREATE OR REPLACE FUNCTION hafah_objects.get_transaction(_trx_hash TEXT, _include_reversible BOOLEAN, _is_old_schema BOOLEAN, _id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN obj FROM (
    SELECT CASE WHEN obj IS NULL OR _ref_block_num IS NULL THEN
      hafah_backend.raise_exception(-32003, format('Assert Exception:false: Unknown Transaction %s', rpad(_trx_hash, 40, '0')), NULL, _id, TRUE)
    ELSE
      obj::JSON
    END
    FROM (
      SELECT
        '{' ||
        '"ref_block_num": ' || _ref_block_num || ', ' ||
        '"ref_block_prefix": ' || _ref_block_prefix || ', ' ||
        '"expiration": "' || _expiration || '", ' ||
        '"operations": ' ||
        (SELECT json_agg(_value) FROM (
          SELECT _value::JSON
          FROM hafah_python.get_ops_in_transaction(_block_num, _trx_in_block, _is_old_schema)
        ) f_call
        ) || ', ' ||
        '"extensions": [], ' ||
        '"signatures": ' ||
        CASE WHEN _multisig_number >= 1 THEN
          array_to_json(ARRAY(
            SELECT _signature
            UNION ALL
            SELECT * FROM hafah_python.get_multi_signatures_in_transaction(_trx_hash::BYTEA)
          ))::TEXT
        ELSE
          '["' || _signature || '"]'
        END
        || ', ' ||
        '"transaction_id": "' || _trx_hash || '", ' ||
        '"block_num": ' || _block_num || ', ' ||
        '"transaction_num": ' || _trx_in_block || ' ' ||
        '}'::TEXT AS obj,
        _ref_block_num
      FROM hafah_python.get_transaction(_trx_hash::BYTEA, _include_reversible)
    ) is_null
  ) to_json;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_objects.enum_virtual_ops(_block_range_begin INT, _block_range_end INT, _operation_begin BIGINT, _limit INT, _filter NUMERIC, _include_reversible BOOLEAN, _group_by_block BOOLEAN, _fill_operation_id BOOLEAN, _id JSON)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __irreversible_block INT;
  __virtual_op_id_offset INT = (SELECT MIN(id) FROM hive.operation_types WHERE is_virtual = True);
BEGIN
  IF _group_by_block IS TRUE THEN
    SELECT hive.app_get_irreversible_block() INTO __irreversible_block;
  END IF;

  RETURN
    CASE WHEN _len > 0 AND _len = _limit THEN
      hafah_objects.do_pagination(_block_range_end, ops_json, _fill_operation_id, _group_by_block, _id)
    ELSE
      jsonb_set(ops_json, '{next_block_range_begin}', to_jsonb(_block_range_end))
    END
  FROM (
    SELECT
      jsonb_build_object(
        'ops', CASE WHEN _group_by_block IS TRUE OR ops IS NULL THEN '[]'::JSON ELSE ops END,
        'ops_by_block', CASE WHEN _group_by_block IS FALSE OR ops IS NULL THEN '[]'::JSON ELSE (SELECT hafah_objects.group_by_block(ops, block_n_arr, __irreversible_block)) END,
        'next_block_range_begin', 0,
        'next_operation_begin', 0
      ) AS ops_json,
      _len
    FROM (
      SELECT
        json_agg(ops::JSON) AS ops,
        array_agg(DISTINCT block_n) AS block_n_arr,
        count(ops)::INT AS _len
      FROM (
        SELECT ops, block_n FROM (
          WITH cte AS (
            SELECT
              NULL::TEXT AS ops,
              NULL::INT AS block_n
            UNION ALL
            SELECT
              hafah_objects.build_api_operation(_trx_id, _block, _trx_in_block, _op_in_trx, _virtual_op, _timestamp, _value, _operation_id, _fill_operation_id, _id),
              _block
            FROM hafah_python.enum_virtual_ops(hafah_backend.translate_filter(_filter, __virtual_op_id_offset), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible)
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

CREATE OR REPLACE FUNCTION hafah_objects.group_by_block(ops JSON, block_n_arr INT[], __irreversible_block INT)
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
          CASE WHEN block_n <= __irreversible_block IS TRUE THEN true ELSE false END || ', ' ||
          '"ops": ' ||
          (SELECT json_agg(ops_elements) FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (ops_elements->>'block')::INT = block_n)
          || ', ' ||
          '"timestamp": "' || 
          (SELECT ops_elements->>'timestamp' FROM (SELECT json_array_elements(ops) AS ops_elements) res WHERE (ops_elements->>'block')::INT = block_n LIMIT 1)
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

CREATE OR REPLACE FUNCTION hafah_objects.do_pagination(_block_range_end INT, ops_json JSONB, _fill_operation_id BOOLEAN, _group_by_block BOOLEAN, _id JSON)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  DROP TABLE IF EXISTS result;

  CREATE TEMP TABLE result AS SELECT
    CASE WHEN o.block_num IS NULL THEN 0 ELSE
      (CASE WHEN o.block_num >= _block_range_end THEN 0 ELSE o.block_num END)
    END AS next_block_range_begin,
    CASE WHEN o.id IS NULL THEN 0 ELSE o.id END AS next_operation_begin
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

  RETURN (
    SELECT jsonb_set(
      (
        SELECT jsonb_set(ops_json,
        '{next_block_range_begin}',
        to_jsonb((SELECT next_block_range_begin FROM result)))
      ),
    '{next_operation_begin}',
    to_jsonb(hafah_objects.set_operation_id(
      (SELECT next_operation_begin FROM result),
      _fill_operation_id, _id)))
  );
END
$$
;
