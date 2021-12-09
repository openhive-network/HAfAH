CREATE SCHEMA IF NOT EXISTS hafah_python;

DROP VIEW IF EXISTS hafah_python.helper_operations_view;
CREATE VIEW hafah_python.helper_operations_view AS SELECT
  id id,
  block_num block_num,
  trx_in_block trx_in_block,
  (
    CASE
      WHEN hov.trx_in_block <= -1 THEN 0
      ELSE abs(hov.op_pos)
    END
  ) ::BIGINT AS op_pos,
  (
    CASE
      WHEN hov.trx_in_block <= -1 THEN hov.op_pos
      ELSE (hov.id - (
        SELECT nahov.id
        FROM hive.operations_view nahov
        JOIN hive.operation_types nhot
        ON nahov.op_type_id = nhot.id
        WHERE nahov.block_num=hov.block_num
        AND nahov.trx_in_block=hov.trx_in_block
        AND nahov.op_pos=hov.op_pos
        AND nhot.is_virtual=FALSE
        LIMIT 1
        )
      )
    END
  ) :: BIGINT AS virtual_op,
  op_type_id op_type_id,
        trim(both '"' from to_json(hov.timestamp)::text) formated_timestamp,
        body body
FROM
  hive.operations_view hov;

CREATE OR REPLACE FUNCTION hafah_python.get_ops_in_block( in _BLOCK_NUM INT, in _ONLY_VIRTUAL BOOLEAN, in _INCLUDE_REVERSIBLE BOOLEAN )
RETURNS TABLE(
    _trx_id TEXT,
    _trx_in_block BIGINT,
    _op_in_trx BIGINT,
    _virtual_op BIGINT,
    _timestamp TEXT,
    _value TEXT,
    _operation_id BIGINT
)
AS
$function$
BEGIN

  IF (NOT _INCLUDE_REVERSIBLE) AND _BLOCK_NUM > hive.app_get_irreversible_block(  ) THEN
    RETURN QUERY SELECT
      NULL::TEXT,
      NULL::BIGINT,
      NULL::BIGINT,
      NULL::BIGINT,
      NULL::TEXT,
      NULL::TEXT,
      NULL::BIGINT
    LIMIT 0;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT
      (
        CASE
        WHEN ht.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
        ELSE encode( ht.trx_hash, 'escape')
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
      T.body _value,
      T.id::BIGINT _operation_id
    FROM
      (
        --`abs` it's temporary, until position of operation is correctly saved
        SELECT
          ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.op_type_id, hot.is_virtual, ho.formated_timestamp as _timestamp, ho.virtual_op
        FROM hafah_python.helper_operations_view ho
        JOIN hive.operation_types hot ON hot.id = ho.op_type_id
        WHERE ho.block_num = _BLOCK_NUM AND ( _ONLY_VIRTUAL = FALSE OR ( _ONLY_VIRTUAL = TRUE AND hot.is_virtual = TRUE ) )
      ) T
      JOIN hive.blocks_view hb ON hb.num = T.block_num
      LEFT JOIN hive.transactions_view ht ON T.block_num = ht.block_num AND T.trx_in_block = ht.trx_in_block
      ORDER BY _operation_id;
END
$function$
language plpgsql STABLE
SET JIT=OFF;

CREATE OR REPLACE FUNCTION hafah_python.get_transaction( in _TRX_HASH BYTEA, in _INCLUDE_REVERSIBLE BOOLEAN )
RETURNS TABLE(
    _ref_block_num INT,
    _ref_block_prefix BIGINT,
    _expiration TEXT,
    _block_num INT,
    _trx_in_block SMALLINT,
    _signature TEXT,
    _multisig_number SMALLINT
)
AS
$function$
DECLARE
  __result hive.transactions_view%ROWTYPE;
  __multisig_number SMALLINT;
BEGIN

  SELECT * INTO __result FROM hive.transactions_view ht WHERE ht.trx_hash = _TRX_HASH;
  IF NOT _INCLUDE_REVERSIBLE AND __result.block_num > hive.app_get_irreversible_block(  ) THEN
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

  SELECT count(*) INTO __multisig_number FROM hive.transactions_multisig_view htm WHERE htm.trx_hash = _TRX_HASH;

  RETURN QUERY
    SELECT
      __result.ref_block_num _ref_block_num,
      __result.ref_block_prefix _ref_block_prefix,
      trim(both '"' from to_json(__result.expiration)::text) _expiration,
      __result.block_num _block_num,
      __result.trx_in_block _trx_in_block,
      encode(__result.signature, 'escape') _signature,
      __multisig_number;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_multi_signatures_in_transaction( in _TRX_HASH BYTEA )
RETURNS TABLE(
    _signature TEXT
)
AS
$function$
BEGIN

  RETURN QUERY
    SELECT
      encode(htm.signature, 'escape') _signature
    FROM hive.transactions_multisig_view htm
    WHERE htm.trx_hash = _TRX_HASH;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_ops_in_transaction( in _BLOCK_NUM INT, in _TRX_IN_BLOCK INT )
RETURNS TABLE(
    _value TEXT
)
AS
$function$
BEGIN
  RETURN QUERY
    SELECT
      ho.body _value
    FROM hive.operations_view ho
    JOIN hive.operation_types hot ON ho.op_type_id = hot.id
    WHERE ho.block_num = _BLOCK_NUM AND ho.trx_in_block = _TRX_IN_BLOCK AND hot.is_virtual = FALSE
    ORDER BY ho.id;
END
$function$
language plpgsql STABLE;

DROP TYPE IF EXISTS hafah_python.enum_virtual_ops_result CASCADE;

CREATE TYPE hafah_python.enum_virtual_ops_result AS ( _trx_id TEXT, _block INT, _trx_in_block BIGINT, _op_in_trx BIGINT, _virtual_op BIGINT, _timestamp TEXT, _value TEXT, _operation_id BIGINT );

CREATE OR REPLACE FUNCTION hafah_python.enum_virtual_ops( in _FILTER INT[], in _BLOCK_RANGE_BEGIN INT, in _BLOCK_RANGE_END INT, _OPERATION_BEGIN BIGINT, in _LIMIT INT, in _INCLUDE_REVERSIBLE BOOLEAN )
RETURNS SETOF hafah_python.enum_virtual_ops_result
AS
$function$
DECLARE
  __upper_block_limit INT;
  __filter_info INT;
  __iterator hafah_python.enum_virtual_ops_result;
  __counter INT := 0;
BEGIN
  SELECT INTO __filter_info ( select array_length( _FILTER, 1 ) );
  IF NOT _INCLUDE_REVERSIBLE THEN
    SELECT hive.app_get_irreversible_block(  ) INTO __upper_block_limit;
    IF _BLOCK_RANGE_BEGIN > __upper_block_limit THEN
      RETURN QUERY SELECT
        NULL::TEXT,
        NULL::INT,
        NULL::BIGINT,
        NULL::BIGINT,
        NULL::BIGINT,
        NULL::TEXT,
        NULL::TEXT,
        NULL::BIGINT
      LIMIT 0;
      RETURN;
    ELSIF __upper_block_limit <= _BLOCK_RANGE_END THEN
      SELECT __upper_block_limit INTO _BLOCK_RANGE_END;
    END IF;
  END IF;

  RETURN QUERY
    SELECT * FROM hafah_python.enum_virtual_ops_impl( _FILTER, _BLOCK_RANGE_BEGIN, _BLOCK_RANGE_END, _OPERATION_BEGIN, _LIMIT, __filter_info )
  UNION ALL
    SELECT
      '',
      _next_block _block,
      0::BIGINT,
      0::BIGINT,
      0::BIGINT,
      ''::TEXT,
      '{"type":"","value":""}'::TEXT,
      _next_op_id _operation_id
    FROM
      hafah_python.enum_virtual_ops_pagination(_FILTER, _BLOCK_RANGE_BEGIN, _BLOCK_RANGE_END, _OPERATION_BEGIN, _LIMIT, __filter_info)
  LIMIT _LIMIT + 1; -- if first query didn't returned _LIMIT + 1 results append additional record with data required to pagination
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.enum_virtual_ops_impl( in _FILTER INT[], in _BLOCK_RANGE_BEGIN INT, in _BLOCK_RANGE_END INT, _OPERATION_BEGIN BIGINT, in _LIMIT INT, in __filter_info INT )
RETURNS SETOF hafah_python.enum_virtual_ops_result
AS
$function$
BEGIN
  RETURN QUERY
    SELECT
      (
        CASE
          WHEN T2.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
          ELSE encode( T2.trx_hash, 'escape')
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
      T.body _value,
      T.id - 1 _operation_id -- 1 is substracted because ho.id start from 1, when it should start from 0
    FROM
    (
      --`abs` it's temporary, until position of operation is correctly saved
      SELECT
      ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.op_type_id, ho.formated_timestamp as _timestamp, ho.virtual_op
      FROM hafah_python.helper_operations_view ho
      JOIN hive.operation_types hot ON hot.id = ho.op_type_id
      WHERE ho.block_num >= _BLOCK_RANGE_BEGIN AND ho.block_num < _BLOCK_RANGE_END
      AND hot.is_virtual = TRUE
      AND ( ( __filter_info IS NULL ) OR ( ho.op_type_id = ANY( _FILTER ) ) )
      AND ( _OPERATION_BEGIN = -1 OR ho.id >= _OPERATION_BEGIN )
      ORDER BY ho.id
      LIMIT _LIMIT + 1
    ) T
    LEFT JOIN
    (
      SELECT block_num, trx_in_block, trx_hash
      FROM hive.transactions_view ht
      WHERE ht.block_num >= _BLOCK_RANGE_BEGIN AND ht.block_num < _BLOCK_RANGE_END
    )T2 ON T.block_num = T2.block_num AND T.trx_in_block = T2.trx_in_block
    WHERE T.block_num >= _BLOCK_RANGE_BEGIN AND T.block_num < _BLOCK_RANGE_END;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.enum_virtual_ops_pagination( in _FILTER INT[], in _BLOCK_RANGE_BEGIN INT, in _BLOCK_RANGE_END INT, _OPERATION_BEGIN BIGINT, in _LIMIT INT, in __filter_info INT )
RETURNS TABLE( _next_block INT, _next_op_id BIGINT )
AS
$function$
BEGIN
  RETURN QUERY
    SELECT
      ho.block_num _next_block,
      ho.id - 1 _next_op_id -- 1 is substracted because ho.id start from 1, when it should start from 0
    FROM   hive.operations_view ho
    JOIN   hive.operation_types hot
    ON   ho.op_type_id=hot.id
    WHERE   hot.is_virtual = TRUE
      AND ( ( __filter_info IS NULL ) OR ( ho.op_type_id = ANY( _FILTER ) ) )
      AND ( _OPERATION_BEGIN = -1 OR ho.id >= _OPERATION_BEGIN )
    AND ho.block_num >= _BLOCK_RANGE_END -- this cannot be set to N+1 block because following block can be empty
    ORDER BY ho.block_num, ho.id
    LIMIT 1;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.ah_get_account_history( in _FILTER INT[], in _ACCOUNT VARCHAR, _START BIGINT, _LIMIT INT, in _INCLUDE_REVERSIBLE BOOLEAN )
RETURNS TABLE(
  _trx_id TEXT,
  _block INT,
  _trx_in_block BIGINT,
  _op_in_trx BIGINT,
  _virtual_op BIGINT,
  _timestamp TEXT,
  _value TEXT,
  _operation_id INT
)
AS
$function$
DECLARE
  __account_id INT;
  __filter_info INT;
  __upper_block_limit INT;
BEGIN

  SELECT INTO __filter_info ( select array_length( _FILTER, 1 ) );

  IF NOT _INCLUDE_REVERSIBLE THEN
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;

  SELECT INTO __account_id ( select id from hive.accounts where name = _ACCOUNT );

  IF __filter_info IS NULL THEN
  RETURN QUERY
    SELECT
      (
        CASE
        WHEN ht.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
        ELSE encode( ht.trx_hash, 'escape')
        END
      ) AS _trx_id,
    T.block_num AS _block,
      (
        CASE
        WHEN ht.trx_in_block IS NULL THEN 4294967295
        ELSE ht.trx_in_block
        END
      ) AS _trx_in_block,
      T.op_pos _op_in_trx,
      T.virtual_op _virtual_op,
      T._timestamp,
      T.body _value,
      T.seq_no as _operation_id
    FROM
    (
      SELECT ho.trx_in_block, ho.id as operation_id, ho.body, ho.op_pos, ho.block_num, X.seq_no, ho.virtual_op, ho.formated_timestamp as _timestamp
      FROM
      (
        SELECT hao.operation_id as operation_id, hao.account_op_seq_no as seq_no
        FROM hive.account_operations_view hao
        WHERE hao.account_id = __account_id AND hao.account_op_seq_no <= _START
        ORDER BY seq_no DESC
        LIMIT _LIMIT
      ) X
    JOIN hafah_python.helper_operations_view ho ON X.operation_id = ho.id
    JOIN hive.operation_types hot ON hot.id = ho.op_type_id
    WHERE ( (__upper_block_limit IS NULL) OR ho.block_num <= __upper_block_limit )
    ORDER BY X.seq_no ASC
    LIMIT _LIMIT ) T
    LEFT JOIN hive.transactions_view ht ON T.block_num = ht.block_num AND T.trx_in_block = ht.trx_in_block;
  ELSE
    RETURN QUERY
      SELECT
        (
          CASE
          WHEN ht.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
          ELSE encode( ht.trx_hash, 'escape')
          END
        ) _trx_id,
        T.block_num _block,
        (
          CASE
          WHEN ht.trx_in_block IS NULL THEN 4294967295
          ELSE ht.trx_in_block
          END
        ) _trx_in_block,
        T.op_pos _op_in_trx,
        T.virtual_op _virtual_op,
        T._timestamp,
        T.body _value,
        T.seq_no as _operation_id
      FROM
        (
          --`abs` it's temporary, until position of operation is correctly saved
          SELECT
            ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.op_type_id, WORKAROUND.seq_no, formated_timestamp as _timestamp, ho.virtual_op
            FROM hafah_python.helper_operations_view ho
          JOIN-- hived patterns related workaround, see more: https://gitlab.syncad.com/hive/HAfAH/-/issues/3
          (
            SELECT
            ho.id, hao.account_op_seq_no as seq_no
            FROM hafah_python.helper_operations_view ho
            JOIN hive.account_operations hao ON ho.id = hao.operation_id
            WHERE ( (__upper_block_limit IS NULL) OR ho.block_num <= __upper_block_limit )
              AND hao.account_id = __account_id
              AND hao.account_op_seq_no <= _START
            ORDER BY seq_no DESC
            LIMIT 2000
          )WORKAROUND ON WORKAROUND.id = ho.id
            WHERE ho.op_type_id = ANY( _FILTER )
            ORDER BY seq_no DESC
            LIMIT _LIMIT
        ) T
        JOIN hive.operation_types hot ON hot.id = T.op_type_id
        LEFT JOIN hive.transactions_view ht ON T.block_num = ht.block_num AND T.trx_in_block = ht.trx_in_block
        ORDER BY _operation_id ASC
        LIMIT _LIMIT;

  END IF;

END
$function$
language plpgsql STABLE
SET JIT=OFF
SET join_collapse_limit=16
SET from_collapse_limit=16
;
DROP VIEW IF EXISTS hafah_python.account_operation_count_info_view CASCADE;
CREATE OR REPLACE VIEW hafah_python.account_operation_count_info_view
AS
SELECT ha.id, ha.name, COALESCE( T.operation_count, 0 ) operation_count
FROM hive.accounts ha
LEFT JOIN
(
SELECT ao.account_id account_id, COUNT(ao.account_op_seq_no) operation_count
FROM hive.account_operations ao
GROUP BY ao.account_id
)T ON ha.id = T.account_id
;

CREATE OR REPLACE FUNCTION hafah_python.remove_redundant_operations( in _CONTEXT_NAME VARCHAR )
RETURNS VOID
AS
$function$
DECLARE
  __CURRENT_BLOCK_NUM INT := 0;
  __DETACHED_BLOCK_NUM INT := 0;
BEGIN

  SELECT current_block_num, detached_block_num INTO __CURRENT_BLOCK_NUM, __DETACHED_BLOCK_NUM FROM hive.contexts WHERE name = _CONTEXT_NAME;

  IF __CURRENT_BLOCK_NUM IS NOT NULL AND __CURRENT_BLOCK_NUM > 0 THEN
    DELETE FROM hive.account_operations
          WHERE hive_rowid IN
          (
            SELECT ao.hive_rowid
            FROM
              hive.contexts c,
              hive.account_operations ao
            JOIN hive.operations o ON ao.operation_id = o.id
            WHERE o.block_num > c.current_block_num AND c.name = _CONTEXT_NAME
          );
  END IF;

  IF __DETACHED_BLOCK_NUM IS NOT NULL AND __DETACHED_BLOCK_NUM > 0 THEN
    DELETE FROM hive.account_operations
          WHERE hive_rowid IN
          (
            SELECT ao.hive_rowid
            FROM
              hive.contexts c,
              hive.account_operations ao
            JOIN hive.operations o ON ao.operation_id = o.id
            WHERE o.block_num > c.detached_block_num AND c.name = _CONTEXT_NAME
          );
  END IF;
END
$function$
language plpgsql;
