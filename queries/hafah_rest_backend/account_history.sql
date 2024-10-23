SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_python.get_account_history_json(
    IN _filter_low NUMERIC,
    IN _filter_high NUMERIC,
    IN _account VARCHAR,
    IN _start BIGINT,
    IN _limit BIGINT,
    IN _include_reversible BOOLEAN,
    IN _is_legacy_style BOOLEAN )
RETURNS JSONB
AS
$function$
BEGIN
  RETURN jsonb_agg(
    json_build_array(
      ops.operation_seq_num,
      (
        CASE
          WHEN _is_legacy_style THEN to_jsonb(ops) - 'operation_id' - 'operation_seq_num'
          ELSE to_jsonb(ops) - 'operation_seq_num'
        END
      )
    )
  )
  FROM (
    SELECT
      _block AS "block",
      _value::JSON AS "op",
      _op_in_trx AS "op_in_trx",
      _timestamp AS "timestamp",
      _trx_id AS "trx_id",
      _trx_in_block AS "trx_in_block",
      _virtual_op AS "virtual_op",
      _operation_id::TEXT AS "operation_id",
      _operation_seq_number AS "operation_seq_num"
    FROM
      hafah_python.get_account_history(
        hafah_python.numeric_to_bigint(_filter_low),
        hafah_python.numeric_to_bigint(_filter_high),
        _account,
        _start,
        _limit,
        _include_reversible,
        _is_legacy_style
      )
  ) ops;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_python.get_account_history(
    IN _filter_low BIGINT,
    IN _filter_high BIGINT,
    IN _account VARCHAR,
    IN _start BIGINT,
    IN _limit BIGINT,
    IN _include_reversible BOOLEAN,
    IN _is_legacy_style BOOLEAN
)
RETURNS TABLE(
  _trx_id TEXT,
  _block INT,
  _trx_in_block BIGINT,
  _op_in_trx BIGINT,
  _virtual_op BOOLEAN,
  _timestamp TEXT,
  _value TEXT,
  _operation_id BIGINT,
  _operation_seq_number INT
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
      NULL :: BIGINT,
      NULL :: INT
    LIMIT 0;
    RETURN;
  END IF;

  SELECT hafah_python.translate_get_account_history_filter(_filter_low, _filter_high) INTO __resolved_filter;

  IF _include_reversible THEN
    SELECT num from hive.blocks_view order by num desc limit 1 INTO __upper_block_limit;
  ELSE
    SELECT hive.app_get_irreversible_block() INTO __upper_block_limit;
  END IF;


  IF _include_reversible THEN
    SELECT INTO __account_id ( select id from hive.accounts_view where name = _account );
  ELSE
    SELECT INTO __account_id ( select id from hafd.accounts where name = _account );
  END IF;

  __use_filter := array_length( __resolved_filter, 1 );

  RETURN QUERY
    WITH pre_result AS
    (
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
        (
          CASE
            WHEN _is_legacy_style THEN hive.get_legacy_style_operation(ho.body_binary)::TEXT
            ELSE ho.body :: text
          END
        ) AS _value,
        ds.operation_id AS _operation_id,
        ds.account_op_seq_no AS _operation_seq_number
      FROM
      (
        WITH accepted_types AS MATERIALIZED
        (
          SELECT ot.id FROM hafd.operation_types ot WHERE __use_filter IS NOT NULL AND ot.id=ANY(__resolved_filter)
        )
        (SELECT hao.operation_id, hao.op_type_id,hao.block_num, hao.account_op_seq_no
        FROM hive.account_operations_view hao
        JOIN accepted_types t ON hao.op_type_id = t.id
        WHERE __use_filter IS NOT NULL AND hao.account_id = __account_id AND hao.account_op_seq_no <= _start AND hao.block_num <= __upper_block_limit 
        ORDER BY hao.account_op_seq_no DESC
        LIMIT _limit
        )
        UNION ALL
        (SELECT hao.operation_id, hao.op_type_id,hao.block_num, hao.account_op_seq_no
        FROM hive.account_operations_view hao
        WHERE __use_filter IS NULL AND hao.account_id = __account_id AND hao.account_op_seq_no <= _start AND hao.block_num <= __upper_block_limit 
        ORDER BY hao.account_op_seq_no DESC
        LIMIT _limit
        )

      ) ds
      JOIN LATERAL (SELECT hov.body, hov.body_binary, hov.op_pos, hov.trx_in_block FROM hive.operations_view hov WHERE ds.operation_id = hov.id) ho ON TRUE
      JOIN LATERAL (select ot.is_virtual FROM hafd.operation_types ot WHERE ds.op_type_id = ot.id) hot on true
      ORDER BY ds.account_op_seq_no ASC

    )
    SELECT -- hafah_python.ah_get_account_history
      pre_result._trx_id,
      pre_result._block,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result.virtual_op,
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS formated_timestamp,
      pre_result._value,
      pre_result._operation_id,
      pre_result._operation_seq_number
    FROM
      pre_result
      JOIN hive.blocks_view hb ON hb.num = pre_result._block
      ORDER BY pre_result._operation_seq_number ASC;

END
$function$
LANGUAGE plpgsql STABLE
SET JIT=OFF
SET join_collapse_limit=16
SET from_collapse_limit=16
SET plan_cache_mode=force_generic_plan
;

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_account(
    _account TEXT,
    _page_num INT,
    _limit INT,
    _filter INT [],
    _from INT,
    _to INT,
    _body_limit INT,
    _rest_of_division INT,
    _ops_count INT
)
RETURNS SETOF hafah_backend.operation -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __account_id INT = (SELECT av.id FROM hive.accounts_view av WHERE av.name = _account);
  __no_start_date BOOLEAN = (_from IS NULL);
  __no_end_date BOOLEAN = (_to IS NULL);
  __no_ops_filter BOOLEAN = (_filter IS NULL);
  __no_filters BOOLEAN := TRUE;
  __offset INT := (((_page_num - 2) * _limit) + (_rest_of_division));
-- offset is calculated only from _page_num = 2, then the offset = _rest_of_division
-- on _page_num = 3, offset = _limit + _rest_of_division etc.
  __op_seq INT:= 0;
BEGIN
IF __no_start_date AND __no_end_date AND __no_ops_filter THEN
  __no_filters = FALSE;
  __op_seq := (_ops_count - (((_page_num - 1) * _limit) + _rest_of_division) );
END IF;


-- 23726 - (237 * 100 + 26) = 0 >= and < 100 
-- 23726 - (236 * 100 + 26) = 100 >= and < 200  

-- 23726 - (0 * 100 + 26) = 23700 >= and < 23800  

RETURN QUERY   
WITH operation_range AS MATERIALIZED (
  SELECT
    ls.operation_id AS id,
    ls.block_num,
    ov.trx_in_block,
    encode(htv.trx_hash, 'hex') AS trx_hash,
    ov.op_pos,
    ls.op_type_id,
    ov.body,
    hot.is_virtual
  FROM (
  WITH op_filter AS MATERIALIZED (
      SELECT ARRAY_AGG(ot.id) as op_id FROM hafd.operation_types ot WHERE (CASE WHEN _filter IS NOT NULL THEN ot.id = ANY(_filter) ELSE TRUE END)
  ),
-- changing filtering method from block_num to operation_id
	ops_from_start_block as MATERIALIZED
	(
		SELECT ov.id 
		FROM hive.operations_view ov
		WHERE ov.block_num >= _from
		ORDER BY ov.block_num, ov.id
		LIMIT 1
	),
	ops_from_end_block as MATERIALIZED
	(
		SELECT ov.id
		FROM hive.operations_view ov
		WHERE ov.block_num <= _to
		ORDER BY ov.block_num DESC, ov.id DESC
		LIMIT 1
	)

  /*
  we are using 3 diffrent methods of fetching data,
  1. using hive_account_operations_uq_1 (account_id, account_op_seq_no) when __no_filters = FALSE (when 2. and 3. are TRUE)
    - when we don't use filter we can page the result by account_op_seq_no, 
      we need to add ORDER BY account_op_seq_no
  2. using hive_account_operations_uq2 (account_id, operation_id) when __no_end_date = FALSE OR __no_start_date = FALSE
    - when we filter operations ONLY by block_num (converted to operation_id), 
      we need to add ORDER BY operation_id
  3. using hive_account_operations_type_account_id_op_seq_idx (op_type_id, account_id, account_op_seq_no) when __no_ops_filter = FALSE
    - when we filter operations by op_type_id 
    - when we filter operations by op_type_id AND block_num (converted to operation_id)
  */ 

    SELECT aov.operation_id, aov.op_type_id, aov.block_num
    FROM hive.account_operations_view aov
    WHERE aov.account_id = __account_id
    AND (__no_filters OR account_op_seq_no >= (CASE WHEN (_rest_of_division) != 0 THEN __op_seq ELSE (__op_seq - _limit) END))
	  AND (__no_filters OR account_op_seq_no < (CASE WHEN (_rest_of_division) != 0 THEN (__op_seq + _limit) ELSE __op_seq END))
    AND (__no_ops_filter OR aov.op_type_id = ANY(ARRAY[(SELECT of.op_id FROM op_filter of)]))
    AND (__no_start_date OR aov.operation_id >= (SELECT * FROM ops_from_start_block))
	  AND (__no_end_date OR aov.operation_id < (SELECT * FROM ops_from_end_block))
    ORDER BY (CASE WHEN NOT __no_start_date OR NOT __no_end_date THEN aov.operation_id ELSE aov.account_op_seq_no END) DESC
    LIMIT (CASE WHEN _page_num = 1 AND (_rest_of_division) != 0 THEN _rest_of_division ELSE _limit END)
    OFFSET (CASE WHEN _page_num = 1 OR NOT __no_filters THEN 0 ELSE __offset END)
  ) ls
  JOIN hive.operations_view ov ON ov.id = ls.operation_id
  JOIN hafd.operation_types hot ON hot.id = ls.op_type_id
  LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ov.trx_in_block
  )
-- filter too long operation bodies 
  SELECT 
    (filtered_operations.composite).body,
    filtered_operations.block_num,
    filtered_operations.trx_hash,
    filtered_operations.op_pos,
    filtered_operations.op_type_id,
    filtered_operations.created_at,
    filtered_operations.is_virtual,
    filtered_operations.id::TEXT,
    filtered_operations.trx_in_block::SMALLINT
  FROM (
  SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
  FROM operation_range ov 
  JOIN hive.blocks_view hb ON hb.num = ov.block_num
  ) filtered_operations
  ORDER BY filtered_operations.id DESC;

END
$$;

-- used in account page endpoint
CREATE OR REPLACE FUNCTION hafah_backend.get_account_operations_count(
    _operations INT [],
    _account TEXT,
    _from INT,
    _to INT
)
RETURNS BIGINT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET from_collapse_limit = 16
SET join_collapse_limit = 16
SET enable_hashjoin = OFF
SET JIT = OFF
AS
$$
DECLARE
  __no_start_date BOOLEAN = (_from IS NULL);
  __no_end_date BOOLEAN = (_to IS NULL);
  __no_ops_filter BOOLEAN = (_operations IS NULL);
BEGIN
IF __no_ops_filter = TRUE AND __no_start_date = TRUE AND __no_end_date = TRUE THEN
  RETURN (
      WITH account_id AS MATERIALIZED (
        SELECT av.id FROM hive.accounts_view av WHERE av.name = _account)

      SELECT aov.account_op_seq_no + 1
      FROM hive.account_operations_view aov
      WHERE aov.account_id = (SELECT ai.id FROM account_id ai) 
      ORDER BY aov.account_op_seq_no DESC LIMIT 1);

ELSE
  RETURN (
    WITH op_filter AS MATERIALIZED (
      SELECT ARRAY_AGG(ot.id) as op_id FROM hafd.operation_types ot WHERE (CASE WHEN _operations IS NOT NULL THEN ot.id = ANY(_operations) ELSE TRUE END)
    ),
    account_id AS MATERIALIZED (
      SELECT av.id FROM hive.accounts_view av WHERE av.name = _account
    ),
-- changing filtering method from block_num to operation_id
    	ops_from_start_block as MATERIALIZED
    (
      SELECT ov.id 
      FROM hive.operations_view ov
      WHERE ov.block_num >= _from
      ORDER BY ov.block_num, ov.id
      LIMIT 1
    ),
    ops_from_end_block as MATERIALIZED
    (
      SELECT ov.id
      FROM hive.operations_view ov
      WHERE ov.block_num <= _to
      ORDER BY ov.block_num DESC, ov.id DESC
      LIMIT 1
    )
-- using hive_account_operations_uq2, we are forcing planner to use this index on (account_id,operation_id), it achives better performance results
    SELECT COUNT(*)
    FROM hive.account_operations_view aov
    WHERE aov.account_id = (SELECT ai.id FROM account_id ai)
    AND (__no_ops_filter OR aov.op_type_id = ANY(ARRAY[(SELECT of.op_id FROM op_filter of)]))
    AND (__no_start_date OR aov.operation_id >= (SELECT * FROM ops_from_start_block))
    AND (__no_end_date OR aov.operation_id < (SELECT * FROM ops_from_end_block))
    );

END IF;
END
$$;


RESET ROLE;
