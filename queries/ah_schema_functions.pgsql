DROP SCHEMA IF EXISTS hafah_python CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_python;

DROP TABLE IF EXISTS hafah_python.version;
CREATE TABLE hafah_python.version(
  git_hash TEXT
);
INSERT INTO hafah_python.version VALUES('unspecified (generate and apply set_version_in_sql.pgsql)');

DROP FUNCTION IF EXISTS hafah_python.get_version;
CREATE OR REPLACE FUNCTION hafah_python.get_version()
  RETURNS TEXT AS $$
DECLARE
  _ BOOLEAN;
BEGIN
  RETURN (SELECT git_hash FROM hafah_python.version LIMIT 1);
END;
$$ LANGUAGE plpgsql;

DROP VIEW IF EXISTS hafah_python.helper_operations_view;
CREATE VIEW hafah_python.helper_operations_view AS SELECT
  hov.id id,
  block_num block_num,
  trx_in_block trx_in_block,
  hov.op_pos ::BIGINT AS op_pos,
  hot.is_virtual AS virtual_op,
  op_type_id op_type_id,
  trim(both '"' from to_json(hov.timestamp)::text) formated_timestamp,
  body body
FROM
  hive.operations_view hov
JOIN
  hive.operation_types hot
ON
  hov.op_type_id=hot.id
;

CREATE OR REPLACE FUNCTION hafah_python.numeric_to_bigint(NUMERIC)
  RETURNS BIGINT AS $$
DECLARE
  MAX_BIGINT BIGINT := x'7fffffffffffffff'::BIGINT;
  MIN_BIGINT BIGINT := (1 :: BIGINT << 63);
BEGIN
  IF $1 IS NULL THEN
    RETURN NULL :: BIGINT;
  END IF;

  IF $1 < 0 THEN
    RETURN NULL;
  ELSEIF $1 > MAX_BIGINT THEN
    RETURN (MIN_BIGINT | ((($1 + MIN_BIGINT) :: BIGINT ))) :: BIGINT;
  ELSE
    RETURN $1 :: BIGINT;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION hafah_python.find_positive_bit(in _N BIGINT, in _START SMALLINT) RETURNS SMALLINT AS $function$
BEGIN
  FOR i IN GREATEST(_START, 0)..63 LOOP
    IF _N & (1 ::BIGINT << i) != 0 THEN
      RETURN i;
    END IF;
  END LOOP;
  RETURN NULL;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_bit_positions_64(in _in BIGINT, in _offset SMALLINT) RETURNS SMALLINT[] AS
$function$
DECLARE
  temp_value BIGINT := 0;
  input_data BIGINT := _in;
  last_found_pos SMALLINT := 0;
  result SMALLINT[] := ARRAY[] ::SMALLINT[];
  MIN_BIGINT_VALUE BIGINT := (1 :: BIGINT << 63);
BEGIN

  IF _in IS NULL THEN
    RETURN NULL :: BIGINT;
  END IF;

  WHILE input_data != 0 LOOP
    IF input_data = MIN_BIGINT_VALUE THEN
      -- substraction from MIN_BIGINT_VALUE will raise exception, that's why
      -- custom behaivior is performed
      input_data := 0;
      last_found_pos := 63;
    ELSE
      temp_value := input_data - 1;
      input_data := input_data & temp_value;
      last_found_pos := hafah_python.find_positive_bit(input_data # (temp_value + 1), last_found_pos);
    END IF;
    result := array_append(result, last_found_pos + _offset );
  END LOOP;

  RETURN result;

END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_bit_positions_128(_low BIGINT, _high BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN (
    SELECT ( (SELECT hafah_python.get_bit_positions_64(_low, 0 :: SMALLINT)) || (SELECT hafah_python.get_bit_positions_64(_high, 64 :: SMALLINT)) )
  );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_python.translate_enum_virtual_ops_filter(_in BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN ( SELECT hafah_python.get_bit_positions_64(_in, (SELECT id FROM hive.operation_types WHERE is_virtual=TRUE ORDER BY id ASC LIMIT 1) ) );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_python.translate_get_account_history_filter(_low BIGINT, _high BIGINT) RETURNS SMALLINT[] AS
$function$
BEGIN
  RETURN ( SELECT hafah_python.get_bit_positions_128(_low, _high ) );
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION hafah_python.validate_limit( in GIVEN_LIMIT BIGINT, in EXPECTED_LIMIT INT ) RETURNS VOID AS $function$
BEGIN
  IF GIVEN_LIMIT > EXPECTED_LIMIT THEN
    RAISE EXCEPTION 'Assert Exception:args.limit <= %: limit of % is greater than maxmimum allowed', EXPECTED_LIMIT, GIVEN_LIMIT;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.validate_negative_limit( in _limit BIGINT ) RETURNS VOID AS $function$
BEGIN
  IF _limit <= 0 THEN
    RAISE EXCEPTION 'Assert Exception:limit > 0: limit of % is lesser or equal 0', _limit;
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_python.validate_start_limit( in _start BIGINT, in _limit BIGINT ) RETURNS VOID AS $function$
BEGIN
  IF _start < (_limit - 1) OR _limit = 0 THEN
    RAISE EXCEPTION 'Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)';
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;


CREATE OR REPLACE FUNCTION hafah_python.validate_block_range( in BLOCK_START INT, in BLOCK_STOP INT, in EXPECTED_DISTANCE INT ) RETURNS VOID AS $function$
BEGIN
  IF BLOCK_STOP - BLOCK_START > EXPECTED_DISTANCE THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd - blockRangeBegin <= block_range_limit: Block range distance must be less than or equal to 2000';
  END IF;

  IF BLOCK_STOP <= BLOCK_START THEN
    RAISE EXCEPTION 'Assert Exception:blockRangeEnd > blockRangeBegin: Block range must be upward';
  END IF;

  RETURN;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_ops_in_block( in _block_num INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
    _trx_id TEXT,
    _trx_in_block BIGINT,
    _op_in_trx BIGINT,
    _virtual_op BOOLEAN,
    _timestamp TEXT,
    _value TEXT,
    _operation_id BIGINT
)
AS
$function$
BEGIN

  IF (NOT _include_reversible) AND _block_num > hive.app_get_irreversible_block() THEN
    RETURN QUERY SELECT
      NULL::TEXT, -- _trx_id
      NULL::BIGINT, -- _trx_in_block
      NULL::BIGINT, -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT, -- _timestamp
      NULL::TEXT, -- _value
      NULL::BIGINT  -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT
      (
        CASE
        WHEN ht.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
        ELSE encode( ht.trx_hash, 'hex')
        END
      ) _trx_id,
      (
        CASE
        WHEN ht.trx_in_block IS NULL THEN 4294967295
        ELSE ht.trx_in_block
        END
      ) _trx_in_block,
      T.op_pos _op_in_trx,
      T.virtual_op _virtual_op,
      T._timestamp,
      (
        CASE
          WHEN _is_legacy_style THEN hive.get_legacy_style_operation(T.body)::text
          ELSE T.body :: text
        END
      ) AS _value,
      T.id::BIGINT _operation_id
    FROM
      (
        --`abs` it's temporary, until position of operation is correctly saved
        SELECT
          ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.op_type_id, ho.virtual_op, ho.formated_timestamp AS _timestamp
        FROM hafah_python.helper_operations_view ho
        WHERE ho.block_num = _block_num AND ( _only_virtual = FALSE OR ( _only_virtual = TRUE AND ho.virtual_op = TRUE ) )
      ) T
      JOIN hive.blocks_view hb ON hb.num = T.block_num
      LEFT JOIN hive.transactions_view ht ON T.block_num = ht.block_num AND T.trx_in_block = ht.trx_in_block
      ORDER BY _operation_id;
END
$function$
language plpgsql STABLE
SET JIT=OFF;

DROP TYPE IF EXISTS hafah_python.get_transaction_result CASCADE;
CREATE TYPE hafah_python.get_transaction_result AS ( _ref_block_num INT, _ref_block_prefix BIGINT, _expiration TEXT, _block_num INT, _trx_in_block SMALLINT, _signature TEXT, _multisig_number SMALLINT );

CREATE OR REPLACE FUNCTION hafah_python.get_transaction( in _trx_hash BYTEA, in _include_reversible BOOLEAN )
RETURNS SETOF hafah_python.get_transaction_result
AS
$function$
DECLARE
  __result hive.transactions_view%ROWTYPE;
  __multisig_number SMALLINT;
BEGIN

  SELECT * INTO __result FROM hive.transactions_view ht WHERE ht.trx_hash = _trx_hash;
  IF NOT _include_reversible AND __result.block_num > hive.app_get_irreversible_block(  ) THEN
    RETURN QUERY SELECT
      NULL::INT,
      NULL::BIGINT,
      NULL::TEXT,
      NULL::INT,
      NULL::SMALLINT,
      NULL::TEXT,
      NULL::SMALLINT
    LIMIT 0;
    RETURN;
  END IF;

  SELECT count(*) INTO __multisig_number FROM hive.transactions_multisig_view htm WHERE htm.trx_hash = _trx_hash;

  RETURN QUERY
    SELECT
      __result.ref_block_num _ref_block_num,
      __result.ref_block_prefix _ref_block_prefix,
      trim(both '"' from to_json(__result.expiration)::text) _expiration,
      __result.block_num _block_num,
      __result.trx_in_block _trx_in_block,
      encode(__result.signature, 'hex') _signature,
      __multisig_number;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_multi_signatures_in_transaction( in _trx_hash BYTEA )
RETURNS TABLE(
    _signature TEXT
)
AS
$function$
BEGIN

  RETURN QUERY
    SELECT
      encode(htm.signature, 'hex') _signature
    FROM hive.transactions_multisig_view htm
    WHERE htm.trx_hash = _trx_hash;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_ops_in_transaction( in _block_num INT, in _trx_in_block INT, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
    _value TEXT
)
AS
$function$
BEGIN
  RETURN QUERY
    SELECT
      (
        CASE
          WHEN _is_legacy_style THEN hive.get_legacy_style_operation(ho.body)::text
          ELSE ho.body :: text
        END
      ) AS _value
    FROM hive.operations_view ho
    JOIN hive.operation_types hot ON ho.op_type_id = hot.id
    WHERE ho.block_num = _block_num AND ho.trx_in_block = _trx_in_block AND hot.is_virtual = FALSE
    ORDER BY ho.id;
END
$function$
language plpgsql STABLE;

DROP TYPE IF EXISTS hafah_python.enum_virtual_ops_result CASCADE;

CREATE TYPE hafah_python.enum_virtual_ops_result AS ( _trx_id TEXT, _block INT, _trx_in_block BIGINT, _op_in_trx BIGINT, _virtual_op BOOLEAN, _timestamp TEXT, _value TEXT, _operation_id BIGINT );

CREATE OR REPLACE FUNCTION hafah_python.enum_virtual_ops( in _filter BIGINT, in _block_range_begin INT, in _block_range_end INT, _operation_begin BIGINT, in _limit INT, in _include_reversible BOOLEAN )
RETURNS SETOF hafah_python.enum_virtual_ops_result
AS
$function$
DECLARE
  __resolved_filter SMALLINT[];
  __upper_block_limit INT;
  __filter_info INT;
BEGIN

  PERFORM hafah_python.validate_negative_limit( _limit );
  PERFORM hafah_python.validate_limit( _limit, 150000 );
  PERFORM hafah_python.validate_block_range( _block_range_begin, _block_range_end, 2000 );

  IF (NOT (_filter IS NULL)) AND _filter = 0 THEN
    RETURN QUERY SELECT
      NULL::TEXT, -- _trx_id
      NULL::INT, -- _block
      NULL::BIGINT, -- _trx_in_block
      NULL::BIGINT, -- _op_in_trx
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT, -- _timestamp
      NULL::TEXT, -- _value
      NULL::BIGINT -- _operation_id
    LIMIT 0;
    RETURN;
  END IF;

  SELECT hafah_python.translate_enum_virtual_ops_filter( _filter ) INTO __resolved_filter;
  SELECT INTO __filter_info ( select array_length( __resolved_filter, 1 ) );

  IF NOT _include_reversible THEN
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
    IF _block_range_begin > __upper_block_limit THEN
      RETURN QUERY SELECT
        NULL::TEXT, -- _trx_id
        NULL::INT, -- _block
        NULL::BIGINT, -- _trx_in_block
        NULL::BIGINT, -- _op_in_trx
        NULL::BOOLEAN, -- _virtual_op
        NULL::TEXT, -- _timestamp
        NULL::TEXT, -- _value
        NULL::BIGINT -- _operation_id
      LIMIT 0;
      RETURN;
    ELSIF __upper_block_limit <= _block_range_end THEN
      SELECT __upper_block_limit INTO _block_range_end;
    END IF;
  END IF;

  RETURN QUERY
    SELECT
      (
        CASE
          WHEN T2.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
          ELSE encode( T2.trx_hash, 'hex')
        END
      ) _trx_id,
      T.block_num _block,
      (
        CASE
          WHEN T2.trx_in_block IS NULL THEN 4294967295
          ELSE T2.trx_in_block
        END
      ) _trx_in_block,
      T.op_pos _op_in_trx,
      T.virtual_op _virtual_op,
      T._timestamp,
      T.body :: text _value,
      T.id _operation_id
    FROM
    (
      --`abs` it's temporary, until position of operation is correctly saved
      SELECT
      ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.op_type_id, ho.formated_timestamp AS _timestamp, ho.virtual_op
      FROM hafah_python.helper_operations_view ho
      WHERE ho.block_num >= _block_range_begin AND ho.block_num < _block_range_end
      AND ho.virtual_op = TRUE
      AND ( ( __filter_info IS NULL ) OR ( ho.op_type_id IN (SELECT * FROM unnest( __resolved_filter ) ) ) )
      AND ( _operation_begin = -1 OR ho.id >= _operation_begin )
      ORDER BY ho.id
      LIMIT _limit
    ) T
    LEFT JOIN
    (
      SELECT block_num, trx_in_block, trx_hash
      FROM hive.transactions_view ht
      WHERE ht.block_num >= _block_range_begin AND ht.block_num < _block_range_end
    )T2 ON T.block_num = T2.block_num AND T.trx_in_block = T2.trx_in_block
    WHERE T.block_num >= _block_range_begin AND T.block_num < _block_range_end
    ORDER BY T.id
    LIMIT _limit;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.ah_get_account_history( in _filter_low BIGINT, in _filter_high BIGINT, in _account VARCHAR, _start BIGINT, _limit BIGINT, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS TABLE(
  _trx_id TEXT,
  _block INT,
  _trx_in_block BIGINT,
  _op_in_trx BIGINT,
  _virtual_op BOOLEAN,
  _timestamp TEXT,
  _value TEXT,
  _operation_id INT
)
AS
$function$
DECLARE
  __resolved_filter SMALLINT[];
  __account_id INT;
  __upper_block_limit INT;
  __use_filter INT;
BEGIN

  PERFORM hafah_python.validate_limit( _limit, 1000 );
  PERFORM hafah_python.validate_start_limit( _start, _limit );

  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL)) AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    RETURN QUERY SELECT
      NULL :: TEXT,
      NULL :: INT,
      NULL :: BIGINT,
      NULL :: BIGINT,
      NULL :: BOOLEAN,
      NULL :: TEXT,
      NULL :: TEXT,
      NULL :: INT
    LIMIT 0;
    RETURN;
  END IF;

  SELECT hafah_python.translate_get_account_history_filter(_filter_low, _filter_high) INTO __resolved_filter;

  IF _include_reversible THEN
    SELECT num from hive.blocks order by num desc limit 1 INTO __upper_block_limit;
  else
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;

  SELECT INTO __account_id ( select id from hive.accounts where name = _account );

  __use_filter := array_length( __resolved_filter, 1 );

  RETURN QUERY
    SELECT -- hafah_python.ah_get_account_history
      (
        CASE
        WHEN ho.trx_in_block < 0 THEN '0000000000000000000000000000000000000000'
        ELSE encode( (SELECT htv.trx_hash FROM hive.transactions_view htv WHERE ho.trx_in_block >= 0 AND ds.block_num = htv.block_num AND ho.trx_in_block = htv.trx_in_block), 'hex')
        END
      ) AS _trx_id,
    ds.block_num AS _block,
      (
        CASE
        WHEN ho.trx_in_block < 0 THEN 4294967295
        ELSE ho.trx_in_block
        END
      ) AS _trx_in_block,
      ho.op_pos::BIGINT AS _op_in_trx,
      hot.is_virtual AS virtual_op,
      btrim(to_json(ho."timestamp")::TEXT, '"'::TEXT) AS formated_timestamp,
      (
        CASE
          WHEN _is_legacy_style THEN hive.get_legacy_style_operation(ho.body)::TEXT
          ELSE ho.body :: text
        END
      ) AS _value,
      ds.account_op_seq_no AS _operation_id
    FROM
    (
      SELECT hao.operation_id, hao.op_type_id,hao.block_num, hao.account_op_seq_no
      FROM hive.account_operations_view hao
      WHERE hao.account_id = __account_id AND hao.account_op_seq_no <= _start AND hao.block_num <= __upper_block_limit AND (__use_filter IS NULL OR hao.op_type_id=ANY(__resolved_filter))
      ORDER BY hao.account_op_seq_no DESC
      LIMIT _limit
    ) ds
    JOIN LATERAL (SELECT hov.body, hov.op_pos, hov.timestamp, hov.trx_in_block FROM hive.operations_view hov WHERE ds.operation_id = hov.id) ho ON TRUE
    JOIN LATERAL (select ot.is_virtual FROM hive.operation_types ot WHERE ds.op_type_id = ot.id) hot on true
    ORDER BY ds.account_op_seq_no ASC

    ;

END
$function$
LANGUAGE plpgsql STABLE
SET JIT=OFF
SET join_collapse_limit=16
SET from_collapse_limit=16
;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hafah_python.get_transaction_json( in _trx_hash BYTEA, in _include_reversible BOOLEAN, _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
DECLARE
  pre_result hafah_python.get_transaction_result;
BEGIN

  SELECT * INTO pre_result FROM hafah_python.get_transaction(_trx_hash, _include_reversible);

  IF NOT FOUND OR pre_result._block_num IS NULL THEN
    RAISE EXCEPTION 'Assert Exception:false: Unknown Transaction %', RPAD(encode(_trx_hash, 'hex'), 40, '0');
  END IF;

  RETURN ( SELECT to_json(a) FROM (
      SELECT
        pre_result._ref_block_num AS "ref_block_num",
        pre_result._ref_block_prefix AS "ref_block_prefix",
        ARRAY[] ::INT[] AS "extensions",
        pre_result._expiration AS "expiration",
        (
          SELECT ARRAY(
            SELECT _value ::JSON FROM hafah_python.get_ops_in_transaction(pre_result._block_num, pre_result._trx_in_block, _is_legacy_style)
          )
        ) AS "operations",
        (
        CASE
          WHEN pre_result._multisig_number = 0 THEN ARRAY[pre_result._signature]
          ELSE (
            array_prepend(
              pre_result._signature,
              (SELECT ARRAY(
                SELECT encode(signature, 'hex') FROM hive.transactions_multisig WHERE trx_hash=_trx_hash
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

CREATE OR REPLACE FUNCTION hafah_python.ah_get_account_history_json( in _filter_low NUMERIC, in _filter_high NUMERIC, in _account VARCHAR, _start BIGINT, _limit BIGINT, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
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
          hafah_python.ah_get_account_history(
            hafah_python.numeric_to_bigint(_filter_low),
            hafah_python.numeric_to_bigint(_filter_high),
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


CREATE OR REPLACE FUNCTION hafah_python.get_ops_in_block_json( in _block_num INT, in _only_virtual BOOLEAN, in _include_reversible BOOLEAN, in _is_legacy_style BOOLEAN )
RETURNS JSON
AS
$function$
BEGIN
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
          hafah_python.get_ops_in_block( _block_num, _only_virtual, _include_reversible, _is_legacy_style )
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


CREATE OR REPLACE FUNCTION hafah_python.enum_virtual_ops_json( in _filter NUMERIC, in _block_range_begin INT, in _block_range_end INT, _operation_begin BIGINT, in _limit INT, in _include_reversible BOOLEAN, in _group_by_block BOOLEAN )
RETURNS JSON
AS
$function$
DECLARE
  irr_num INT;
BEGIN
  irr_num := (x'7fffffff' :: BIGINT :: INT);
  IF _include_reversible = TRUE AND _group_by_block = TRUE THEN
    SELECT hive.app_get_irreversible_block() INTO irr_num;
  END IF;

  RETURN (
    WITH
      pre_result AS (
        SELECT
          _block AS "block",
          _value ::json AS "op",
          _op_in_trx AS "op_in_trx",
          _operation_id AS "operation_id",
          _timestamp AS "timestamp",
          _trx_id AS "trx_id",
          _trx_in_block AS "trx_in_block",
          _virtual_op AS "virtual_op"
        FROM hafah_python.enum_virtual_ops( hafah_python.numeric_to_bigint(_filter), _block_range_begin, _block_range_end, _operation_begin, _limit, _include_reversible )
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
        FROM hive.operations o
        JOIN hive.operation_types ot ON o.op_type_id = ot.id
        WHERE
          ot.is_virtual=TRUE
          AND o.block_num>=(SELECT blk FROM pre_result_in)
          AND o.id>(SELECT op_id FROM pre_result_in)
        ORDER BY o.block_num, o.id
        LIMIT 1
      )

    SELECT to_json(result)
    FROM (
      SELECT
        COALESCE((SELECT block_num FROM pag), (
          CASE
            WHEN _block_range_end > (SELECT num FROM hive.blocks ORDER BY num DESC LIMIT 1) THEN 0
            ELSE _block_range_end
          END
        )) AS next_block_range_begin,
        COALESCE((
          CASE
            WHEN (SELECT block_num FROM pag) >= _block_range_end THEN 0
            ELSE (SELECT id FROM pag)
          END
        ), 0) AS next_operation_begin,
        (
          CASE
            WHEN _group_by_block = FALSE THEN (
              SELECT ARRAY(
                SELECT to_json(res) FROM (
                  SELECT * FROM pre_result
                ) AS res
              )
            )
            ELSE (SELECT ARRAY[] ::JSON[])
          END
        ) AS ops,
        (
          CASE
            WHEN _group_by_block = TRUE THEN (
              SELECT ARRAY(
                SELECT to_json(grouped) FROM (
                  SELECT
                    pre_result.block AS "block",
                    (pre_result.block <= irr_num) AS "irreversible",
                    array_agg(pre_result) AS "ops",
                    (SELECT pr.timestamp FROM pre_result pr WHERE pr.block=pre_result.block ORDER BY pr.operation_id ASC LIMIT 1) AS "timestamp"
                  FROM pre_result
                  GROUP BY pre_result.block
                  ORDER BY pre_result.block ASC
                ) AS grouped
              )
            )
            ELSE (SELECT ARRAY[] ::JSON[])
          END
        ) AS ops_by_block
    ) AS result
  );

END
$function$
language plpgsql STABLE;
