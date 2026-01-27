SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_transaction_json( in _trx_hash BYTEA, in _include_reversible BOOLEAN, _is_legacy_style BOOLEAN, _include_virtual BOOLEAN = FALSE)
RETURNS JSON
AS
$function$
DECLARE
  pre_result hafah_backend.get_transaction_result;
BEGIN

  SELECT * INTO pre_result FROM hafah_backend.get_transaction(_trx_hash, _include_reversible);

  IF NOT FOUND OR pre_result._block_num IS NULL THEN
    RAISE EXCEPTION 'Assert Exception:false: Unknown Transaction %', RPAD(encode(_trx_hash, 'hex'), 40, '0');
  END IF;

  IF pre_result._block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  RETURN ( SELECT to_json(a) FROM (
      SELECT
        pre_result._ref_block_num AS "ref_block_num",
        pre_result._ref_block_prefix AS "ref_block_prefix",
        ARRAY[] ::INT[] AS "extensions",
        pre_result._expiration AS "expiration",
        (
          SELECT ARRAY(
            SELECT _value ::JSON FROM hafah_backend.get_ops_in_transaction(pre_result._block_num, pre_result._trx_in_block, _is_legacy_style, _include_virtual)
          )
        ) AS "operations",
        (
        CASE
          WHEN pre_result._multisig_number = 0 AND pre_result._signature IS NOT NULL
            THEN ARRAY[pre_result._signature]
          WHEN pre_result._multisig_number = 0 AND pre_result._signature IS  NULL
            THEN '{}'
          ELSE (
            array_prepend(
              pre_result._signature,
              (SELECT ARRAY(
                SELECT encode(signature, 'hex') FROM hive.transactions_multisig_view WHERE trx_hash=_trx_hash
              ))
            )
          )
          END
        ) AS "signatures",
        encode(_trx_hash, 'hex') AS "transaction_id",
        pre_result._block_num AS "block_num",
        pre_result._trx_in_block AS "transaction_num"
    ) a
  );

END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.ah_get_account_history_json( in _filter_low NUMERIC, in _filter_high NUMERIC, in _account VARCHAR, _start BIGINT, _limit BIGINT, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
BEGIN
  RETURN (
    WITH result AS (SELECT ARRAY(
      SELECT json_build_array(
        ops.operation_id,
        (
          CASE
            WHEN _is_legacy_style THEN to_jsonb(ops) - 'operation_id'
            ELSE jsonb_set(to_jsonb(ops), ARRAY['operation_id']::TEXT[], '0'::JSONB, FALSE)
          END
        )
        ) FROM (
        SELECT
          _block AS "block",
          _value ::json AS "op",
          _op_in_trx AS "op_in_trx",
          _timestamp AS "timestamp",
          _trx_id AS "trx_id",
          _trx_in_block AS "trx_in_block",
          _virtual_op AS "virtual_op",
          _operation_id AS "operation_id"
        FROM
          hafah_backend.ah_get_account_history(
            hafah_backend.numeric_to_bigint(_filter_low),
            hafah_backend.numeric_to_bigint(_filter_high),
            _account,
            _start,
            _limit,
            _include_reversible,
            _is_legacy_style
          )
      ) ops
    ) AS a)
    SELECT
    (
      CASE
        WHEN _is_legacy_style THEN to_json(result.a)
        ELSE json_build_object('history', to_json(result.a))
      END
    )
    FROM result
  );
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_block_json( in _block_num INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
BEGIN
  IF _block_num <= hive.app_get_irreversible_block() THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  RETURN (
    WITH result AS (SELECT ARRAY(
      SELECT
        CASE
          WHEN _is_legacy_style THEN to_jsonb(ops) - 'operation_id'
          ELSE to_jsonb(ops)
        END
      FROM (
        SELECT
          _block_num AS "block",
          _value ::json AS "op",
          _op_in_trx AS "op_in_trx",
          _timestamp AS "timestamp",
          _trx_id AS "trx_id",
          _trx_in_block AS "trx_in_block",
          _virtual_op AS "virtual_op",
          0 AS "operation_id"
        FROM
          hafah_backend.get_ops_in_block( _block_num, _only_virtual, _include_reversible, _is_legacy_style )
      ) ops
    ) AS a )
    SELECT
    (
      CASE
        WHEN _is_legacy_style THEN to_json(result.a)
        ELSE json_build_object('ops', to_json(result.a))
      END
    )
    FROM result
  );
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_backend.enum_virtual_ops_json( in _filter NUMERIC, in _block_range_begin INT, in _block_range_end INT, _operation_begin BIGINT, in _limit INT, in _include_reversible BOOLEAN, in _group_by_block BOOLEAN )
RETURNS JSONB
AS
$function$
DECLARE
  irr_num INT;
  actual_last_irreversible_block_number INT;
BEGIN
  SELECT hive.app_get_irreversible_block() INTO actual_last_irreversible_block_number;
  IF _block_range_end <= actual_last_irreversible_block_number THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=3"}]', true);
  END IF;

  irr_num := (x'7fffffff' :: BIGINT :: INT);
  IF _include_reversible = TRUE AND _group_by_block = TRUE THEN
    irr_num := actual_last_irreversible_block_number;
  END IF;

  RETURN (
    WITH
      pre_result AS (
        SELECT
          _block AS "block",
          _value ::jsonb AS "op",
          _op_in_trx AS "op_in_trx",
          _operation_id AS "operation_id",
          _timestamp AS "timestamp",
          _trx_id AS "trx_id",
          _trx_in_block AS "trx_in_block",
          _virtual_op AS "virtual_op"
        FROM hafah_backend.enum_virtual_ops( hafah_backend.numeric_to_bigint(_filter), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible )
      ),
      pag AS (
        WITH pre_result_in AS (
              SELECT
                (
                  CASE
                    WHEN (SELECT COUNT(*) FROM pre_result) = _limit THEN
                      pre_result.block
                    ELSE
                      _block_range_end
                  END
                ) AS blk,
                pre_result.operation_id AS op_id
              FROM pre_result
              WHERE pre_result.operation_id = (SELECT MAX(pre_result.operation_id) FROM pre_result)
              LIMIT 1
        )
        SELECT o.block_num, o.id
        FROM hive.operations_view o
        JOIN hafd.operation_types ot ON o.op_type_id = ot.id
        WHERE
          ot.is_virtual=TRUE
          AND o.block_num>=(SELECT blk FROM pre_result_in)
          AND o.id>(SELECT op_id FROM pre_result_in)
        ORDER BY o.block_num, o.id
        LIMIT 1
      )

    SELECT to_jsonb(result)
    FROM (
      SELECT
        COALESCE((SELECT block_num FROM pag), (
          CASE
            WHEN _block_range_end > (SELECT num FROM hafd.blocks ORDER BY num DESC LIMIT 1) THEN 0
            ELSE _block_range_end
          END
        )) AS next_block_range_begin,
        hafah_backend.json_stringify_bigint(COALESCE((
          CASE
            WHEN (SELECT block_num FROM pag) >= _block_range_end THEN 0
            ELSE (SELECT id FROM pag)
          END
        ), 0)) AS next_operation_begin,
        (
          CASE
            WHEN _group_by_block = FALSE THEN (
              SELECT ARRAY(
                SELECT to_jsonb(res) FROM (
                  SELECT
                    s.block,
                    s.op,
                    s.op_in_trx,
                    hafah_backend.json_stringify_bigint(s.operation_id) AS "operation_id",
                    s.timestamp,
                    s.trx_id,
                    s.trx_in_block,
                    s.virtual_op
                  FROM pre_result s
                ) AS res
              )
            )
            ELSE (SELECT ARRAY[] ::JSONB[])
          END
        ) AS ops,
        (
          CASE
            WHEN _group_by_block = TRUE THEN (
              SELECT ARRAY(
                SELECT to_jsonb(grouped) FROM (
                  SELECT
                    ds.block AS "block",
                    (ds.block <= irr_num) AS "irreversible",
                    array_agg(ds) AS "ops",
                    (SELECT pr.timestamp FROM pre_result pr WHERE pr.block=ds.block ORDER BY pr.operation_id ASC LIMIT 1) AS "timestamp"
                  FROM
                  (
                  SELECT
                    s.block,
                    s.op,
                    s.op_in_trx,
                    hafah_backend.json_stringify_bigint(s.operation_id) AS "operation_id",
                    s.timestamp,
                    s.trx_id,
                    s.trx_in_block,
                    s.virtual_op
                  FROM pre_result s
                  ) AS ds
                  GROUP BY ds.block
                  ORDER BY ds.block ASC
                ) AS grouped
              )
            )
            ELSE (SELECT ARRAY[] ::JSONB[])
          END
        ) AS ops_by_block
    ) AS result
  );

END
$function$
language plpgsql STABLE;

RESET ROLE;
