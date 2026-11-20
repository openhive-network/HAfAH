-- ah_get_account_history, which reads each page's operations and blocks as
-- id-sorted batches and skips the transaction probe of virtual operations,
-- returns the rows of the per-row statement it replaced. The per-row function
-- is restated below in pg_temp, comments dropped, as the reference. On the
-- shared HAF (block 5000000) it compares the md5 of both functions' rows, legacy
-- and new style, on newest and deep pages of limits 1 to 1000: blocktrades
-- (virtual-heavy: producer and curation rewards), steemit (transaction-heavy),
-- riswanjana with its comment of seq 45 cached as in
-- rendered_operation_cache_check.sql, and filters on blocktrades that take the
-- common-type and the rare-type branch. It fails when a case set misses one
-- of those: no rows, no virtual-heavy page, no cached row or a branch not taken.
-- Runs as haf_shared_consumer in the run's clone (.aidev/run-checks.sh install),
-- inside a transaction it rolls back.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL ROLE hafah_owner;

CREATE FUNCTION pg_temp.ah_get_account_history_per_row(
    _filter_low         BIGINT,
    _filter_high        BIGINT,
    _account            VARCHAR,
    _start              BIGINT,
    _limit              BIGINT,
    _is_legacy_style    BOOLEAN
)
RETURNS TABLE(
    _trx_id       TEXT,
    _block        INT,
    _trx_in_block BIGINT,
    _op_in_trx    BIGINT,
    _virtual_op   BOOLEAN,
    _timestamp    TEXT,
    _value        JSONB,
    _operation_id INT,
    _cached_entry JSON
)
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET plan_cache_mode = force_custom_plan
AS $$
DECLARE
  __resolved_filter       SMALLINT[];
  __account_id            INT;
  __upper_operation_id    BIGINT;
  __last_seq              INT;
  __rare_types            BOOLEAN := FALSE;
BEGIN
  PERFORM hafah_backend.validate_limit(_limit, 1000);
  PERFORM hafah_backend.validate_start_limit(_start, _limit);
  IF (NOT (_filter_low IS NULL AND _filter_high IS NULL))
     AND COALESCE(_filter_low, 0) + COALESCE(_filter_high, 0) = 0 THEN
    RETURN;
  END IF;
  __resolved_filter := hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high);

  __upper_operation_id := hafd.operation_id(hive.app_get_irreversible_block() + 1, 0);

  __account_id := (SELECT ha.id FROM hafd.accounts ha WHERE ha.name = _account);

  IF __resolved_filter IS NOT NULL THEN
    __last_seq := (
      SELECT ao.account_op_seq_no
      FROM hafd.account_operations ao
      WHERE ao.account_id = __account_id
        AND ao.account_op_seq_no <= _start
        AND ao.operation_id < __upper_operation_id
      ORDER BY ao.account_op_seq_no DESC
      LIMIT 1
    );

    __rare_types := hafah_backend.account_op_types_are_rare(
      __resolved_filter::INT[], __account_id, 0, __last_seq, _limit::INT
    );
  END IF;

  RETURN QUERY
    SELECT
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN '0000000000000000000000000000000000000000'
          ELSE encode(ht.trx_hash, 'hex')
        END
      ) AS _trx_id,
      blk.block_num AS _block,
      (
        CASE
          WHEN ho.trx_in_block < 0
            THEN 4294967295
          ELSE ho.trx_in_block
        END
      ) AS _trx_in_block,
      ho.op_pos AS _op_in_trx,
      ho.virtual_op AS _virtual_op,
      btrim(to_json(hb.created_at)::TEXT, '"'::TEXT) AS _timestamp,
      (
        CASE
          WHEN roc.operation_id IS NOT NULL
            THEN NULL
          WHEN _is_legacy_style
            THEN hive.get_legacy_style_operation(hafd._operation_from_jsonb(ho.body))::JSONB
          ELSE ho.body
        END
      ) AS _value,
      page.account_op_seq_no AS _operation_id,
      (
        CASE
          WHEN _is_legacy_style
            THEN roc.legacy_entry
          ELSE roc.entry
        END
      ) AS _cached_entry
    FROM (
      (
        SELECT ao.operation_id, ao.account_op_seq_no
        FROM hafd.account_operations ao
        WHERE __resolved_filter IS NULL
          AND ao.account_id = __account_id
          AND ao.account_op_seq_no <= _start
          AND ao.operation_id < __upper_operation_id
        ORDER BY ao.account_op_seq_no DESC
        LIMIT _limit
      )
      UNION ALL
      (
        SELECT ao.operation_id, seqs.account_op_seq_no
        FROM (
          SELECT s.account_op_seq_no
          FROM hafd.account_operations s
          WHERE __resolved_filter IS NOT NULL AND NOT __rare_types
            AND s.account_id = __account_id
            AND s.account_op_seq_no <= __last_seq
            AND (s.op_type_id = ANY(__resolved_filter)) IS TRUE
          ORDER BY s.account_op_seq_no DESC
          LIMIT _limit
        ) seqs
        CROSS JOIN LATERAL (
          SELECT ao.operation_id
          FROM hafd.account_operations ao
          WHERE ao.account_id = __account_id
            AND ao.account_op_seq_no = seqs.account_op_seq_no
            AND ao.operation_id < __upper_operation_id
          LIMIT 1
        ) ao
      )
      UNION ALL
      (
        SELECT rare.operation_id, rare.account_op_seq_no
        FROM (
          SELECT ao.operation_id, ao.account_op_seq_no
          FROM hafd.account_operations ao
          WHERE __rare_types
            AND ao.account_id = __account_id
            AND ao.op_type_id = ANY(__resolved_filter)
            AND ao.account_op_seq_no <= _start
            AND ao.operation_id < __upper_operation_id
          OFFSET 0
        ) rare
        ORDER BY rare.account_op_seq_no DESC
        LIMIT _limit
      )
      LIMIT _limit
    ) page
    CROSS JOIN LATERAL (SELECT hafd.operation_id_to_block_num(page.operation_id) AS block_num) blk
    JOIN hafah_backend.helper_operations_view ho ON ho.id = page.operation_id
    JOIN hafd.blocks hb ON hb.num = blk.block_num
    LEFT JOIN LATERAL (
      SELECT tx.trx_hash FROM hafd.transactions tx
      WHERE tx.block_num = blk.block_num AND tx.trx_in_block = ho.trx_in_block
      LIMIT 1
    ) ht ON TRUE
    LEFT JOIN hafah_backend.rendered_operation_cache roc ON roc.operation_id = page.operation_id
    ORDER BY page.account_op_seq_no ASC;
END
$$;

CREATE TEMP TABLE batched_fetch_cases ON COMMIT DROP AS
SELECT c.*, s.is_legacy_style
FROM (VALUES
  -- account,     filter_low, filter_high, start, limit; start -1 normalized as the dispatcher does
  ('blocktrades', NULL::BIGINT, NULL::BIGINT, hafah_backend.parse_acc_hist_start(-1),    1::BIGINT),
  ('blocktrades', NULL,         NULL,         hafah_backend.parse_acc_hist_start(-1),  100),
  ('blocktrades', NULL,         NULL,         hafah_backend.parse_acc_hist_start(-1), 1000),
  ('blocktrades', NULL,         NULL,         100000,                                 1000),
  ('blocktrades', NULL,         NULL,         999,                                    1000),
  ('steemit',     NULL,         NULL,         hafah_backend.parse_acc_hist_start(-1), 1000),
  ('steemit',     NULL,         NULL,         2000,                                    100),
  ('riswanjana',  NULL,         NULL,         45,                                        1),
  ('riswanjana',  NULL,         NULL,         60,                                       30),
  ('riswanjana',  NULL,         NULL,         hafah_backend.parse_acc_hist_start(-1), 1000),
  -- transfer_operation (type 2): common for blocktrades
  ('blocktrades', 4,            0,            hafah_backend.parse_acc_hist_start(-1), 1000),
  ('blocktrades', 4,            0,            50000,                                   100),
  -- witness_update_operation (type 11): rare for blocktrades
  ('blocktrades', 2048,         0,            hafah_backend.parse_acc_hist_start(-1),  100),
  -- comment_operation (type 1) on riswanjana: selects the cached op
  ('riswanjana',  2,            0,            hafah_backend.parse_acc_hist_start(-1),  100)
) AS c (account, filter_low, filter_high, start, lim)
CROSS JOIN (VALUES (TRUE), (FALSE)) AS s (is_legacy_style);

DO $$
DECLARE
  _case RECORD;
  _batched TEXT;
  _per_row TEXT;
  _rows INT;
  _virtual INT;
  _cached INT;
  _filter SMALLINT[];
  _account_id INT;
  _last_seq INT;
  _virtual_heavy BOOLEAN := FALSE;
  _cached_seen BOOLEAN := FALSE;
  _common_seen BOOLEAN := FALSE;
  _rare_seen BOOLEAN := FALSE;
BEGIN
  IF hafah_backend.refresh_rendered_operation_cache(_operation_ids => ARRAY[13550325466136578]) <> 1 THEN
    RAISE EXCEPTION 'refresh_rendered_operation_cache did not cache riswanjana''s comment 13550325466136578';
  END IF;

  FOR _case IN SELECT * FROM batched_fetch_cases LOOP
    SELECT md5(string_agg(f::TEXT, E'\n' ORDER BY f._operation_id)), count(*),
           count(*) FILTER (WHERE f._virtual_op), count(*) FILTER (WHERE f._cached_entry IS NOT NULL)
    INTO _batched, _rows, _virtual, _cached
    FROM hafah_backend.ah_get_account_history(
      _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim, _case.is_legacy_style) f;

    SELECT md5(string_agg(f::TEXT, E'\n' ORDER BY f._operation_id))
    INTO _per_row
    FROM pg_temp.ah_get_account_history_per_row(
      _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim, _case.is_legacy_style) f;

    IF _rows = 0 THEN
      RAISE EXCEPTION 'ah_get_account_history(%, %, %, %, %) returned no rows; the case compares nothing',
        _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim;
    END IF;
    IF _batched IS DISTINCT FROM _per_row THEN
      RAISE EXCEPTION 'ah_get_account_history(%, %, %, %, %, legacy %) differs from the per-row statement: md5 % against %',
        _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim, _case.is_legacy_style,
        _batched, _per_row;
    END IF;

    _virtual_heavy := _virtual_heavy OR (_rows >= 100 AND _virtual * 10 >= _rows * 9);
    _cached_seen := _cached_seen OR _cached > 0;

    IF _case.filter_low IS NOT NULL THEN
      _filter := hafah_backend.translate_get_account_history_filter(_case.filter_low, _case.filter_high);
      _account_id := (SELECT ha.id FROM hafd.accounts ha WHERE ha.name = _case.account);
      _last_seq := (
        SELECT ao.account_op_seq_no FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id AND ao.account_op_seq_no <= _case.start
        ORDER BY ao.account_op_seq_no DESC LIMIT 1
      );
      IF hafah_backend.account_op_types_are_rare(_filter::INT[], _account_id, 0, _last_seq, _case.lim::INT) THEN
        _rare_seen := TRUE;
      ELSE
        _common_seen := TRUE;
      END IF;
    END IF;
  END LOOP;

  IF NOT (_virtual_heavy AND _cached_seen AND _common_seen AND _rare_seen) THEN
    RAISE EXCEPTION 'the cases miss a kind of page: virtual-heavy %, cached op %, common-type branch %, rare-type branch %',
      _virtual_heavy, _cached_seen, _common_seen, _rare_seen;
  END IF;

  RAISE NOTICE 'ah_get_account_history''s batched fetches return the per-row statement''s rows on % cases',
    (SELECT count(*) FROM batched_fetch_cases);
END
$$;

ROLLBACK;
