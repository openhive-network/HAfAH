-- get_account_history through hafah_backend.rendered_operation_cache gives the
-- bytes it gives without it. On the shared HAF (block 5000000, below the HF23
-- hardfork_hive operation) the install leaves the cache empty; this check
-- caches the largest comment of the chain, riswanjana's at account_op_seq_no 45
-- of 0..197 (operation 13550325466136578, ~1 MB stored), through
-- refresh_rendered_operation_cache's explicit id list, and compares the md5 of
-- ah_get_account_history_json's text, legacy and new style, with the op alone,
-- at both edges of a page, mid-page, over the whole history and under filters
-- that select and exclude it. Then hafah_user, PostgREST's role, calls
-- hafah_endpoints.home on the cached page.
-- Runs as haf_shared_consumer in the run's clone (.aidev/run-checks.sh install).
-- The cache table is hafah_owner's, so the check writes it as hafah_owner inside
-- its own transaction and rolls it back.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL ROLE hafah_owner;

CREATE TEMP TABLE rendered_cache_cases ON COMMIT DROP AS
SELECT c.*, s.is_legacy_style, NULL::TEXT AS uncached_md5
FROM (VALUES
  -- account,     filter_low, filter_high, start, limit; start -1 normalized as the dispatcher does
  ('riswanjana',  NULL::NUMERIC, NULL::NUMERIC,  45::BIGINT,    1::BIGINT),
  ('riswanjana',  NULL,          NULL,           45,           10),
  ('riswanjana',  NULL,          NULL,           54,           10),
  ('riswanjana',  NULL,          NULL,           60,           30),
  ('riswanjana',  NULL,          NULL,           hafah_backend.parse_acc_hist_start(-1),         1000),
  -- comment_operation (type 1) only: selects it; vote_operation (type 0) only: excludes it
  ('riswanjana',  2,             0,              hafah_backend.parse_acc_hist_start(-1),          100),
  ('riswanjana',  1,             0,              hafah_backend.parse_acc_hist_start(-1),          100),
  ('riswanjana',  0,             0,              hafah_backend.parse_acc_hist_start(-1),          100),
  ('steemit',     NULL,          NULL,           hafah_backend.parse_acc_hist_start(-1),          100)
) AS c (account, filter_low, filter_high, start, lim)
CROSS JOIN (VALUES (TRUE), (FALSE)) AS s (is_legacy_style);

UPDATE rendered_cache_cases c
SET uncached_md5 = md5(hafah_backend.ah_get_account_history_json(
      c.filter_low, c.filter_high, c.account, c.start, c.lim, c.is_legacy_style)::TEXT);

DO $$
DECLARE
  _cached INT;
BEGIN
  IF EXISTS (SELECT 1 FROM hafah_backend.rendered_operation_cache) THEN
    RAISE EXCEPTION 'rendered_operation_cache is not empty after install on a chain below block 41818752';
  END IF;

  _cached := hafah_backend.refresh_rendered_operation_cache(_operation_ids => ARRAY[13550325466136578]);
  IF _cached <> 1 THEN
    RAISE EXCEPTION 'refresh_rendered_operation_cache cached % operations, expected 1', _cached;
  END IF;

  -- The page row of the cached op takes the cached path: no body, a pre-rendered entry
  IF NOT EXISTS (
    SELECT 1 FROM hafah_backend.ah_get_account_history(NULL, NULL, 'riswanjana', 45, 1, TRUE)
    WHERE _operation_id = 45 AND _value IS NULL AND _cached_entry IS NOT NULL
  ) OR NOT EXISTS (
    SELECT 1 FROM hafah_backend.ah_get_account_history(NULL, NULL, 'riswanjana', 45, 1, FALSE)
    WHERE _operation_id = 45 AND _value IS NULL AND _cached_entry IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'ah_get_account_history does not serve riswanjana''s seq 45 from the cache';
  END IF;
END
$$;

DO $$
DECLARE
  _case RECORD;
  _got TEXT;
BEGIN
  FOR _case IN SELECT * FROM rendered_cache_cases LOOP
    _got := md5(hafah_backend.ah_get_account_history_json(
      _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim, _case.is_legacy_style)::TEXT);
    IF _got IS DISTINCT FROM _case.uncached_md5 THEN
      RAISE EXCEPTION 'ah_get_account_history_json(%, %, %, %, %, legacy %) differs with the op cached: md5 % against %',
        _case.filter_low, _case.filter_high, _case.account, _case.start, _case.lim, _case.is_legacy_style,
        _got, _case.uncached_md5;
    END IF;
  END LOOP;

  RAISE NOTICE 'get_account_history output is byte-identical with and without the cached op';
END
$$;

-- hafah_user's expected answers, computed with the cache filled: the comparison
-- above makes them today's answers too. Settings, not a table, as hafah_user
-- cannot read hafah_owner's temp tables.
DO $$
BEGIN
  PERFORM set_config('hafah_check.legacy', hafah_backend.ah_get_account_history_json(NULL, NULL, 'riswanjana', 50, 10, TRUE)::TEXT, TRUE);
  PERFORM set_config('hafah_check.new', hafah_backend.ah_get_account_history_json(NULL, NULL, 'riswanjana', 50, 10, FALSE)::TEXT, TRUE);
END
$$;

SET LOCAL ROLE hafah_user;

DO $$
DECLARE
  _legacy JSONB;
  _new JSONB;
BEGIN
  _legacy := hafah_endpoints.home('{"jsonrpc": "2.0", "id": 1, "method": "condenser_api.get_account_history", "params": ["riswanjana", 50, 10]}');
  _new := hafah_endpoints.home('{"jsonrpc": "2.0", "id": 1, "method": "account_history_api.get_account_history", "params": {"account": "riswanjana", "start": 50, "limit": 10}}');
  IF _legacy->'result' IS DISTINCT FROM current_setting('hafah_check.legacy')::JSONB THEN
    RAISE EXCEPTION 'condenser_api.get_account_history as hafah_user answered %', left(_legacy::TEXT, 500);
  END IF;
  IF _new->'result' IS DISTINCT FROM current_setting('hafah_check.new')::JSONB THEN
    RAISE EXCEPTION 'account_history_api.get_account_history as hafah_user answered %', left(_new::TEXT, 500);
  END IF;

  RAISE NOTICE 'hafah_user gets get_account_history pages through the cache';
END
$$;

ROLLBACK;
