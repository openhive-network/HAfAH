-- The six REST account history variants behind hafah_backend.get_ops_by_account,
-- which read each page's operations and blocks as id-sorted batches and skip the
-- transaction probe of virtual operations, return the composite of the per-row
-- statements they replaced. Those are restated below in pg_temp, comments
-- dropped, as the reference. On the shared HAF (block 5000000) it compares the
-- md5 of both functions' results, which the endpoint renders as its JSON, for
-- each variant: newest, oldest and middle pages of sizes 1 to 1000, to-block
-- pinned, blocktrades (virtual-heavy: producer and curation rewards) and steemit
-- (transaction-heavy), common and rare type filters, single and multiple
-- include and exclude partners (the multiple-account variants are not reachable
-- through REST), and a data-size-limit that replaces bodies with the
-- placeholder. It fails when a variant returns no rows on every case, or when
-- no case has a virtual-heavy page or a placeholder body.
-- Runs as haf_shared_consumer in the run's clone (.aidev/run-checks.sh install),
-- inside a transaction it rolls back.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL ROLE hafah_owner;

CREATE FUNCTION pg_temp.account_history_default_per_row(
    _account_id INT,
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  _calculate_pages hafah_backend.calculate_pages_return;
  _ops_count INT;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  _ops_count := hafah_backend.get_account_operations_count(NULL, _account_id, _account_range.from_seq, _account_range.to_seq);
  _calculate_pages := hafah_backend.calculate_pages(_ops_count, _page, 'desc', _limit);
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM (
      SELECT ao.operation_id, ao.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM hafd.account_operations ao
      WHERE ao.account_id = _account_id
      AND ao.account_op_seq_no >= _account_range.from_seq
      AND ao.account_op_seq_no <= _account_range.to_seq - _calculate_pages.offset_filter
      ORDER BY ao.account_op_seq_no DESC
      LIMIT _calculate_pages.limit_filter
    ) ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.operation_id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block::SMALLINT
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM operation_range ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
  )
  SELECT array_agg(rows ORDER BY rows.id DESC)
  INTO _result
  FROM (
    SELECT
      s.body,
      s.block_num,
      s.trx_hash,
      s.op_pos,
      s.op_type_id,
      s.created_at,
      s.is_virtual,
      s.id::TEXT,
      s.trx_in_block
    FROM result_query s
  ) rows;
  RETURN (
    COALESCE(_ops_count,0),
    COALESCE(_calculate_pages.total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE FUNCTION pg_temp.account_history_by_operations_per_row(
    _account_id INT,
    _operations INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  _calculate_pages hafah_backend.calculate_pages_return;
  _ops_count INT;
  _rare_types BOOLEAN;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  _ops_count := hafah_backend.get_account_operations_count(_operations, _account_id, _account_range.from_seq, _account_range.to_seq);
  _calculate_pages := hafah_backend.calculate_pages(_ops_count, _page, 'desc', _limit);
  _rare_types := COALESCE(
    _ops_count < hafah_backend.account_rare_match_threshold(
      _calculate_pages.offset_filter + _calculate_pages.limit_filter,
      _account_range.to_seq::BIGINT - _account_range.from_seq + 1
    ),
    FALSE
  );
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM (
      (
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT _rare_types
          AND s.account_id = _account_id
          AND (_operations IS NULL OR (s.op_type_id = ANY(_operations)) IS TRUE)
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          LIMIT _calculate_pages.limit_filter
          OFFSET _calculate_pages.offset_filter
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE _rare_types
          AND ao.account_id = _account_id
          AND ao.op_type_id = ANY(_operations)
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          OFFSET 0
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT _calculate_pages.limit_filter
        OFFSET _calculate_pages.offset_filter
      )
    ) ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.operation_id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM operation_range ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
  )
  SELECT array_agg(rows ORDER BY rows.id DESC)
  INTO _result
  FROM (
    SELECT
      s.body,
      s.block_num,
      s.trx_hash,
      s.op_pos,
      s.op_type_id,
      s.created_at,
      s.is_virtual,
      s.id::TEXT,
      s.trx_in_block
    FROM result_query s
  ) rows;
  RETURN (
    COALESCE(_ops_count,0),
    COALESCE(_calculate_pages.total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE FUNCTION pg_temp.account_history_include_account_per_row(
    _account_id INT,
    _operations INT [],
    _transacting_account_id INT,
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;
  __total_pages INT;
  __min_block_num INT;
  __count INT;
  __rare_matches hafah_backend.account_op_match[];
  __rare_types BOOLEAN;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  __rare_matches := hafah_backend.account_rare_op_matches(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1, ARRAY[_transacting_account_id]
  );
  __rare_types := __rare_matches IS NOT NULL;
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      (
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types AND _operations IS NULL
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0
        ) walk
        WHERE walk.transacting_account_id = _transacting_account_id
        AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT __rare_types AND _operations IS NOT NULL
          AND s.account_id = _account_id
          AND (s.op_type_id = ANY(_operations)) IS TRUE
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          OFFSET 0
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id, ao.transacting_account_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
        WHERE ao.transacting_account_id = _transacting_account_id
        ORDER BY seqs.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM unnest(__rare_matches) rare
        WHERE __rare_types
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
    ) ls
  ),
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  filter_by_op_seq AS MATERIALIZED (
    (
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types AND _operations IS NULL
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0
      ) walk
      WHERE walk.transacting_account_id = _transacting_account_id
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT ao.operation_id AS id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM (
        SELECT s.account_op_seq_no, s.op_type_id
        FROM hafd.account_operations s
        WHERE NOT __rare_types AND _operations IS NOT NULL
        AND s.account_id = _account_id
        AND (s.op_type_id = ANY(_operations)) IS TRUE
        AND s.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND s.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY s.account_op_seq_no DESC
        OFFSET 0
      ) seqs
      CROSS JOIN LATERAL (
        SELECT ao.operation_id, ao.transacting_account_id
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
        AND ao.account_op_seq_no = seqs.account_op_seq_no
        LIMIT 1
      ) ao
      WHERE ao.transacting_account_id = _transacting_account_id
      ORDER BY seqs.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM unnest(__rare_matches) rare
      WHERE __rare_types
      AND (
        (SELECT account_op_seq_no FROM block_check) IS NOT NULL
        AND rare.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
      )
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit
    )
  ),
  find_all_records_for_page AS (
    SELECT
      ls.id,
      ls.block_num,
      ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT
      id,
      block_num,
      op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT
      id,
      block_num,
      op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
      FROM (
        SELECT
          s.body,
          s.block_num,
          s.trx_hash,
          s.op_pos,
          s.op_type_id,
          s.created_at,
          s.is_virtual,
          s.id::TEXT,
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE FUNCTION pg_temp.account_history_including_accounts_per_row(
    _account_id INT,
    _operations INT [],
    _transacting_account_ids INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;
  __total_pages INT;
  __min_block_num INT;
  __count INT;
  __rare_matches hafah_backend.account_op_match[];
  __rare_types BOOLEAN;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  __rare_matches := hafah_backend.account_rare_op_matches(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1, _transacting_account_ids
  );
  __rare_types := __rare_matches IS NOT NULL;
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      (
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types AND _operations IS NULL
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0
        ) walk
        WHERE walk.transacting_account_id = ANY(_transacting_account_ids)
        AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT __rare_types AND _operations IS NOT NULL
          AND s.account_id = _account_id
          AND (s.op_type_id = ANY(_operations)) IS TRUE
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          OFFSET 0
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id, ao.transacting_account_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
        WHERE ao.transacting_account_id = ANY(_transacting_account_ids)
        ORDER BY seqs.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM unnest(__rare_matches) rare
        WHERE __rare_types
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
    ) ls
  ),
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  filter_by_op_seq AS MATERIALIZED (
    (
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types AND _operations IS NULL
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0
      ) walk
      WHERE walk.transacting_account_id = ANY(_transacting_account_ids)
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT ao.operation_id AS id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM (
        SELECT s.account_op_seq_no, s.op_type_id
        FROM hafd.account_operations s
        WHERE NOT __rare_types AND _operations IS NOT NULL
        AND s.account_id = _account_id
        AND (s.op_type_id = ANY(_operations)) IS TRUE
        AND s.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND s.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY s.account_op_seq_no DESC
        OFFSET 0
      ) seqs
      CROSS JOIN LATERAL (
        SELECT ao.operation_id, ao.transacting_account_id
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
        AND ao.account_op_seq_no = seqs.account_op_seq_no
        LIMIT 1
      ) ao
      WHERE ao.transacting_account_id = ANY(_transacting_account_ids)
      ORDER BY seqs.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM unnest(__rare_matches) rare
      WHERE __rare_types
      AND (
        (SELECT account_op_seq_no FROM block_check) IS NOT NULL
        AND rare.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
      )
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit
    )
  ),
  find_all_records_for_page AS (
    SELECT ls.id, ls.block_num, ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT id, block_num, op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT id, block_num, op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
      FROM (
        SELECT
          s.body,
          s.block_num,
          s.trx_hash,
          s.op_pos,
          s.op_type_id,
          s.created_at,
          s.is_virtual,
          s.id::TEXT,
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE FUNCTION pg_temp.account_history_exclude_account_per_row(
    _account_id INT,
    _operations INT [],
    _transacting_account_id INT,
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;
  __total_pages INT;
  __min_block_num INT;
  __count INT;
  __rare_types BOOLEAN;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  __rare_types := hafah_backend.account_op_types_are_rare(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1
  );
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      (
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types AND _operations IS NULL
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0
        ) walk
        WHERE walk.transacting_account_id != _transacting_account_id
        AND walk.transacting_account_id IS NOT NULL
        AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT __rare_types AND _operations IS NOT NULL
          AND s.account_id = _account_id
          AND (s.op_type_id = ANY(_operations)) IS TRUE
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          OFFSET 0
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id, ao.transacting_account_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
        WHERE ao.transacting_account_id != _transacting_account_id
        AND ao.transacting_account_id IS NOT NULL
        ORDER BY seqs.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
          AND ao.account_id = _account_id
          AND ao.transacting_account_id != _transacting_account_id
          AND ao.transacting_account_id IS NOT NULL
          AND ao.op_type_id = ANY(_operations)
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          OFFSET 0
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
    ) ls
  ),
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  filter_by_op_seq AS MATERIALIZED (
    (
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types AND _operations IS NULL
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0
      ) walk
      WHERE walk.transacting_account_id != _transacting_account_id
      AND walk.transacting_account_id IS NOT NULL
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT ao.operation_id AS id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM (
        SELECT s.account_op_seq_no, s.op_type_id
        FROM hafd.account_operations s
        WHERE NOT __rare_types AND _operations IS NOT NULL
        AND s.account_id = _account_id
        AND (s.op_type_id = ANY(_operations)) IS TRUE
        AND s.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND s.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY s.account_op_seq_no DESC
        OFFSET 0
      ) seqs
      CROSS JOIN LATERAL (
        SELECT ao.operation_id, ao.transacting_account_id
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
        AND ao.account_op_seq_no = seqs.account_op_seq_no
        LIMIT 1
      ) ao
      WHERE ao.transacting_account_id != _transacting_account_id
      AND ao.transacting_account_id IS NOT NULL
      ORDER BY seqs.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE __rare_types
        AND ao.account_id = _account_id
        AND ao.transacting_account_id != _transacting_account_id
        AND ao.transacting_account_id IS NOT NULL
        AND ao.op_type_id = ANY(_operations)
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        OFFSET 0
      ) rare
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit
    )
  ),
  find_all_records_for_page AS (
    SELECT ls.id, ls.block_num, ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT id, block_num, op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT id, block_num, op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
      FROM (
        SELECT
          s.body,
          s.block_num,
          s.trx_hash,
          s.op_pos,
          s.op_type_id,
          s.created_at,
          s.is_virtual,
          s.id::TEXT,
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE FUNCTION pg_temp.account_history_excluding_accounts_per_row(
    _account_id INT,
    _operations INT [],
    _transacting_account_ids INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT
)
RETURNS hafah_backend.account_operation_history
LANGUAGE 'plpgsql' STABLE
COST 10000
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS
$$
DECLARE
  _result hafah_backend.operation[];
  _account_range hafah_backend.account_filter_return;
  __max_page_count INT := 10;
  __total_pages INT;
  __min_block_num INT;
  __count INT;
  __rare_types BOOLEAN;
BEGIN
  _account_range := hafah_backend.account_range(_account_id, _from_block, _to_block);
  __rare_types := hafah_backend.account_op_types_are_rare(
    _operations, _account_id, _account_range.from_seq, _account_range.to_seq,
    (__max_page_count * _limit) + 1
  );
  WITH
  operation_range AS MATERIALIZED (
    SELECT
      ls.operation_id AS id,
      ls.block_num,
      ls.op_type_id,
      ls.account_op_seq_no,
      ROW_NUMBER() OVER (ORDER BY ls.operation_id DESC) AS row_num
    FROM (
      (
        SELECT walk.operation_id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num, walk.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE NOT __rare_types AND _operations IS NULL
          AND ao.account_id = _account_id
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          ORDER BY ao.account_op_seq_no DESC
          OFFSET 0
        ) walk
        WHERE (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
        AND NOT (walk.transacting_account_id = ANY(_transacting_account_ids))
        AND walk.transacting_account_id IS NOT NULL
        ORDER BY walk.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT ao.operation_id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no, s.op_type_id
          FROM hafd.account_operations s
          WHERE NOT __rare_types AND _operations IS NOT NULL
          AND s.account_id = _account_id
          AND (s.op_type_id = ANY(_operations)) IS TRUE
          AND s.account_op_seq_no >= _account_range.from_seq
          AND s.account_op_seq_no <= _account_range.to_seq
          ORDER BY s.account_op_seq_no DESC
          OFFSET 0
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id, ao.transacting_account_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = _account_id
          AND ao.account_op_seq_no = seqs.account_op_seq_no
          LIMIT 1
        ) ao
        WHERE NOT (ao.transacting_account_id = ANY(_transacting_account_ids))
        AND ao.transacting_account_id IS NOT NULL
        ORDER BY seqs.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
          AND ao.account_id = _account_id
          AND ao.op_type_id = ANY(_operations)
          AND ao.account_op_seq_no >= _account_range.from_seq
          AND ao.account_op_seq_no <= _account_range.to_seq
          AND NOT (ao.transacting_account_id = ANY(_transacting_account_ids))
          AND ao.transacting_account_id IS NOT NULL
          OFFSET 0
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT (__max_page_count * _limit) + 1
      )
    ) ls
  ),
  check_if_saturated AS (
    SELECT (
      CASE
        WHEN MAX(row_num) = (__max_page_count * _limit) + 1 THEN
          (__max_page_count * _limit) + 1
        ELSE
          NULL
      END
    ) AS count
    FROM operation_range
  ),
  if_saturated_find_last_two_ops AS (
    SELECT
      orr.block_num,
      orr.account_op_seq_no
    FROM operation_range orr
    WHERE orr.row_num IN (
      (SELECT count FROM check_if_saturated),
      (SELECT count - 1 FROM check_if_saturated)
    )
  ),
  block_check AS MATERIALIZED (
    SELECT (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(block_num)
        ELSE NULL
      END
    ) AS block_num,
    (
      CASE
        WHEN COUNT(DISTINCT block_num) = 1 THEN MIN(account_op_seq_no)
        ELSE NULL
      END
    ) AS account_op_seq_no
    FROM if_saturated_find_last_two_ops
  ),
  filter_by_op_seq AS MATERIALIZED (
    (
      SELECT walk.operation_id AS id, walk.op_type_id, hafd.operation_id_to_block_num(walk.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.transacting_account_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE NOT __rare_types AND _operations IS NULL
        AND ao.account_id = _account_id
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY ao.account_op_seq_no DESC
        OFFSET 0
      ) walk
      WHERE NOT (walk.transacting_account_id = ANY(_transacting_account_ids))
      AND walk.transacting_account_id IS NOT NULL
      AND (_operations IS NULL OR (walk.op_type_id = ANY(_operations)) IS TRUE)
      ORDER BY walk.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT ao.operation_id AS id, seqs.op_type_id, hafd.operation_id_to_block_num(ao.operation_id) AS block_num
      FROM (
        SELECT s.account_op_seq_no, s.op_type_id
        FROM hafd.account_operations s
        WHERE NOT __rare_types AND _operations IS NOT NULL
        AND s.account_id = _account_id
        AND (s.op_type_id = ANY(_operations)) IS TRUE
        AND s.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND s.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        ORDER BY s.account_op_seq_no DESC
        OFFSET 0
      ) seqs
      CROSS JOIN LATERAL (
        SELECT ao.operation_id, ao.transacting_account_id
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
        AND ao.account_op_seq_no = seqs.account_op_seq_no
        LIMIT 1
      ) ao
      WHERE NOT (ao.transacting_account_id = ANY(_transacting_account_ids))
      AND ao.transacting_account_id IS NOT NULL
      ORDER BY seqs.account_op_seq_no DESC
      LIMIT _limit
    )
    UNION ALL
    (
      SELECT rare.operation_id AS id, rare.op_type_id, hafd.operation_id_to_block_num(rare.operation_id) AS block_num
      FROM (
        SELECT ao.operation_id, ao.op_type_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE __rare_types
        AND ao.account_id = _account_id
        AND NOT (ao.transacting_account_id = ANY(_transacting_account_ids))
        AND ao.transacting_account_id IS NOT NULL
        AND ao.op_type_id = ANY(_operations)
        AND ao.account_op_seq_no >= _account_range.from_seq
        AND (
          (SELECT account_op_seq_no FROM block_check) IS NOT NULL
          AND ao.account_op_seq_no <= (SELECT account_op_seq_no FROM block_check)
        )
        OFFSET 0
      ) rare
      ORDER BY rare.account_op_seq_no DESC
      LIMIT _limit
    )
  ),
  find_all_records_for_page AS (
    SELECT ls.id, ls.block_num, ls.op_type_id
    FROM filter_by_op_seq ls
    WHERE
      (SELECT block_num FROM block_check) IS NOT NULL AND
      ls.block_num = (SELECT block_num FROM block_check)
  ),
  union_operations AS MATERIALIZED (
    SELECT id, block_num, op_type_id
    FROM operation_range
    WHERE row_num <= (__max_page_count * _limit)
    UNION ALL
    SELECT id, block_num, op_type_id
    FROM find_all_records_for_page
  ),
  min_block_num AS (
    SELECT MIN(block_num) AS block_num
    FROM union_operations
  ),
  count_blocks AS MATERIALIZED (
    SELECT COUNT(*) AS count
    FROM union_operations
  ),
  calculate_pages AS MATERIALIZED (
    SELECT total_pages, offset_filter, limit_filter
    FROM hafah_backend.calculate_pages(
      (SELECT count FROM count_blocks)::INT,
      _page,
      'desc',
      _limit
    )
  ),
  filter_page AS (
    SELECT *
    FROM union_operations
    ORDER BY id DESC
    OFFSET (SELECT offset_filter FROM calculate_pages)
    LIMIT (SELECT limit_filter FROM calculate_pages)
  ),
  join_tables AS (
    SELECT
      ls.id,
      ls.block_num,
      ho.trx_in_block,
      encode(ht.trx_hash, 'hex') AS trx_hash,
      ho.op_pos::INT AS op_pos,
      ls.op_type_id,
      ho.body,
      ho.virtual_op AS is_virtual
    FROM filter_page ls
    JOIN hafah_backend.helper_operations_view ho ON ho.id = ls.id
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash, tx.trx_in_block FROM hafd.transactions tx
      WHERE tx.block_num = ls.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
  ),
  result_query AS (
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id,
      filtered_operations.trx_in_block
    FROM (
      SELECT hafah_backend.operation_body_filter(ov.body, ov.id, _body_limit) as composite, ov.id, ov.block_num, ov.trx_in_block, ov.trx_hash, ov.op_pos, ov.op_type_id, ov.is_virtual, hb.created_at
      FROM join_tables ov
      JOIN hafd.blocks hb ON hb.num = ov.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id DESC
  )
  SELECT
    (SELECT count FROM count_blocks),
    (SELECT total_pages FROM calculate_pages),
    (SELECT block_num FROM min_block_num),
    (
      SELECT array_agg(rows ORDER BY rows.id::BIGINT DESC)
      FROM (
        SELECT
          s.body,
          s.block_num,
          s.trx_hash,
          s.op_pos,
          s.op_type_id,
          s.created_at,
          s.is_virtual,
          s.id::TEXT,
          s.trx_in_block::SMALLINT
        FROM result_query s
      ) rows
    )
  INTO __count, __total_pages, __min_block_num, _result;
  _account_range.from_block := (
    CASE
      WHEN __min_block_num IS NULL THEN _account_range.from_block
      WHEN __min_block_num IS NOT NULL AND __min_block_num = 1 THEN 1
      WHEN __min_block_num IS NOT NULL AND __min_block_num != 1 AND __count < __max_page_count * _limit THEN _account_range.from_block
      ELSE __min_block_num - 1
    END
  );
  RETURN (
    COALESCE(__count,0),
    COALESCE(__total_pages,0),
    (_account_range.from_block, _account_range.to_block)::hafah_backend.block_range_type,
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.account_operation_history;
END
$$;

CREATE TEMP TABLE rest_batched_fetch_cases ON COMMIT DROP AS
WITH acc AS (SELECT ha.name, ha.id FROM hafd.accounts ha),
op AS (SELECT ot.name, ot.id::INT AS id FROM hafd.operation_types ot)
SELECT c.variant, a.id AS account_id, c.operations, c.partners, c.from_block, c.to_block, c.page, c.body_limit, c.lim
FROM (VALUES
  -- variant,          account,       operation type names, partner names,  from, to_block, page, body_limit, limit
  ('default',          'blocktrades', NULL::TEXT[],         NULL::TEXT[],   1, 5000000, NULL::INT,  200000,    1),
  ('default',          'blocktrades', NULL,                 NULL,           1, 5000000, NULL,       200000,  100),
  ('default',          'blocktrades', NULL,                 NULL,           1, 5000000, NULL,       200000, 1000),
  ('default',          'blocktrades', NULL,                 NULL,           1, 5000000, 1,          200000, 1000),
  ('default',          'blocktrades', NULL,                 NULL,           1, 3000000, 2,          200000,  100),
  ('default',          'blocktrades', NULL,                 NULL,           1, 5000000, NULL,          100, 1000),
  ('default',          'steemit',     NULL,                 NULL,           1, 5000000, NULL,       200000, 1000),
  ('default',          'steemit',     NULL,                 NULL,           1, 5000000, 1,          200000,  100),
  ('by_operations',    'blocktrades', ARRAY['hive::protocol::producer_reward_operation'], NULL, 1, 5000000, NULL, 200000, 1000),
  ('by_operations',    'blocktrades', ARRAY['hive::protocol::transfer_operation'],        NULL, 1, 5000000, NULL, 200000, 1000),
  ('by_operations',    'blocktrades', ARRAY['hive::protocol::transfer_operation'],        NULL, 1, 5000000, 1,    200000,  100),
  ('by_operations',    'blocktrades', ARRAY['hive::protocol::witness_update_operation'],  NULL, 1, 5000000, NULL, 200000,  100),
  ('by_operations',    'steemit',     ARRAY['hive::protocol::transfer_operation', 'hive::protocol::account_create_operation'], NULL, 1, 5000000, NULL, 100, 1000),
  ('include_account',  'blocktrades', NULL,                 ARRAY['blocktrades'], 1, 5000000, NULL, 200000, 1000),
  ('include_account',  'blocktrades', NULL,                 ARRAY['blocktrades'], 1, 5000000, 3,    200000,  100),
  ('include_account',  'blocktrades', NULL,                 ARRAY['gtg'],         1, 5000000, NULL, 200000,  100),
  ('include_account',  'blocktrades', ARRAY['hive::protocol::transfer_operation'], ARRAY['blocktrades'], 1, 5000000, NULL, 200000, 100),
  ('include_account',  'steemit',     NULL,                 ARRAY['steemit'],     1, 5000000, NULL,    100,    1),
  ('including_accounts', 'blocktrades', NULL,               ARRAY['blocktrades', 'gtg'], 1, 5000000, NULL, 200000, 1000),
  ('including_accounts', 'blocktrades', NULL,               ARRAY['blocktrades', 'gtg'], 1, 5000000, 2,    200000,  100),
  ('including_accounts', 'blocktrades', ARRAY['hive::protocol::transfer_operation'], ARRAY['blocktrades', 'steemit'], 1, 5000000, NULL, 100, 100),
  ('exclude_account',  'blocktrades', NULL,                 ARRAY['blocktrades'], 1, 5000000, NULL, 200000, 1000),
  ('exclude_account',  'blocktrades', NULL,                 ARRAY['blocktrades'], 1, 3000000, 2,    200000,  100),
  ('exclude_account',  'blocktrades', ARRAY['hive::protocol::producer_reward_operation'], ARRAY['gtg'], 1, 5000000, NULL, 200000, 1000),
  ('exclude_account',  'steemit',     NULL,                 ARRAY['steemit'],     1, 5000000, NULL,    100,    1),
  ('excluding_accounts', 'blocktrades', NULL,               ARRAY['blocktrades', 'gtg'], 1, 5000000, NULL, 200000, 1000),
  ('excluding_accounts', 'blocktrades', NULL,               ARRAY['blocktrades', 'gtg'], 1, 5000000, 2,    200000,  100),
  ('excluding_accounts', 'steemit',   ARRAY['hive::protocol::transfer_operation'], ARRAY['steemit', 'blocktrades'], 1, 5000000, NULL, 100, 1000)
) AS c0 (variant, account, operation_names, partner_names, from_block, to_block, page, body_limit, lim)
JOIN acc a ON a.name = c0.account
CROSS JOIN LATERAL (
  SELECT c0.variant, c0.from_block, c0.to_block, c0.page, c0.body_limit, c0.lim,
    (SELECT array_agg(op.id ORDER BY op.id) FROM op WHERE op.name = ANY(c0.operation_names)) AS operations,
    (SELECT array_agg(acc.id ORDER BY array_position(c0.partner_names, acc.name::TEXT)) FROM acc WHERE acc.name = ANY(c0.partner_names)) AS partners,
    cardinality(c0.operation_names) AS n_operations, cardinality(c0.partner_names) AS n_partners
) c
-- A name that does not resolve drops its case, which the count below reports
WHERE cardinality(c.operations) IS NOT DISTINCT FROM c.n_operations
  AND cardinality(c.partners) IS NOT DISTINCT FROM c.n_partners;

DO $$
DECLARE
  _case RECORD;
  _call TEXT;
  _batched hafah_backend.account_operation_history;
  _per_row hafah_backend.account_operation_history;
  _rows INT;
  _virtual INT;
  _placeholders INT;
  _cases INT;
  _variants_with_rows TEXT[] := '{}';
  _virtual_heavy BOOLEAN := FALSE;
  _placeholder_seen BOOLEAN := FALSE;
BEGIN
  _cases := (SELECT count(*) FROM rest_batched_fetch_cases);
  IF _cases <> 28 THEN
    RAISE EXCEPTION 'only % of the 28 cases resolved their accounts and operation types', _cases;
  END IF;

  FOR _case IN SELECT * FROM rest_batched_fetch_cases LOOP
    _call := CASE _case.variant
      WHEN 'default' THEN format('(%s, %s, %s, %L::INT, %s, %s)',
        _case.account_id, _case.from_block, _case.to_block, _case.page, _case.body_limit, _case.lim)
      WHEN 'by_operations' THEN format('(%s, %L::INT[], %s, %s, %L::INT, %s, %s)',
        _case.account_id, _case.operations, _case.from_block, _case.to_block, _case.page, _case.body_limit, _case.lim)
      WHEN 'include_account' THEN format('(%s, %L::INT[], %s, %s, %s, %L::INT, %s, %s)',
        _case.account_id, _case.operations, _case.partners[1], _case.from_block, _case.to_block, _case.page, _case.body_limit, _case.lim)
      WHEN 'exclude_account' THEN format('(%s, %L::INT[], %s, %s, %s, %L::INT, %s, %s)',
        _case.account_id, _case.operations, _case.partners[1], _case.from_block, _case.to_block, _case.page, _case.body_limit, _case.lim)
      ELSE format('(%s, %L::INT[], %L::INT[], %s, %s, %L::INT, %s, %s)',
        _case.account_id, _case.operations, _case.partners, _case.from_block, _case.to_block, _case.page, _case.body_limit, _case.lim)
    END;

    EXECUTE format('SELECT * FROM hafah_backend.account_history_%s%s', _case.variant, _call) INTO _batched;
    EXECUTE format('SELECT * FROM pg_temp.account_history_%s_per_row%s', _case.variant, _call) INTO _per_row;

    IF md5(_batched::TEXT) IS DISTINCT FROM md5(_per_row::TEXT) THEN
      RAISE EXCEPTION 'account_history_% % differs from the per-row statement: md5 % against %',
        _case.variant, _call, md5(_batched::TEXT), md5(_per_row::TEXT);
    END IF;

    SELECT count(*), count(*) FILTER (WHERE o.virtual_op),
           count(*) FILTER (WHERE o.op->>'type' = 'body_placeholder_operation')
    INTO _rows, _virtual, _placeholders
    FROM unnest(_batched.operations_result) o;

    IF _rows > 0 AND NOT _case.variant = ANY(_variants_with_rows) THEN
      _variants_with_rows := _variants_with_rows || _case.variant;
    END IF;
    _virtual_heavy := _virtual_heavy OR (_rows >= 100 AND _virtual * 10 >= _rows * 9);
    _placeholder_seen := _placeholder_seen OR _placeholders > 0;
  END LOOP;

  IF cardinality(_variants_with_rows) <> 6 THEN
    RAISE EXCEPTION 'only variants % returned rows; the others compare nothing', _variants_with_rows;
  END IF;
  IF NOT (_virtual_heavy AND _placeholder_seen) THEN
    RAISE EXCEPTION 'the cases miss a kind of page: virtual-heavy %, placeholder body %',
      _virtual_heavy, _placeholder_seen;
  END IF;

  RAISE NOTICE 'the REST account history variants'' batched fetches return the per-row statements'' results on % cases', _cases;
END
$$;

ROLLBACK;
