-- Every REST endpoint function in hafah_endpoints is STABLE or IMMUTABLE, so
-- PostgREST runs its POST calls (the rewriter forwards REST GETs as POSTs) in
-- a READ ONLY transaction, as it does for VOLATILE functions only on GET.
-- The JSON-RPC dispatcher functions (first argument JSON) are POSTed by their
-- clients and are not checked. Then the endpoints whose volatility was once
-- missing are called inside a READ ONLY transaction, on the shared HAF at
-- blocks 1000-1010.
-- Runs as haf_shared_consumer in the run's clone (.aidev/run-checks.sh install)
-- and writes nothing.
\set ON_ERROR_STOP on

DO $$
DECLARE
  _volatile TEXT;
BEGIN
  SELECT string_agg(p.oid::regprocedure::TEXT, ', ' ORDER BY p.proname)
  INTO _volatile
  FROM pg_proc p
  WHERE p.pronamespace = 'hafah_endpoints'::regnamespace
    AND p.provolatile = 'v'
    AND (p.pronargs = 0 OR p.proargtypes[0] <> 'json'::regtype);

  IF _volatile IS NOT NULL THEN
    RAISE EXCEPTION 'REST endpoint functions declared VOLATILE: %', _volatile;
  END IF;

  RAISE NOTICE 'every REST endpoint function in hafah_endpoints is STABLE or IMMUTABLE';
END
$$;

BEGIN READ ONLY;

DO $$
BEGIN
  IF current_setting('transaction_read_only') <> 'on' THEN
    RAISE EXCEPTION 'the endpoint calls are not running in a READ ONLY transaction';
  END IF;

  PERFORM hafah_endpoints.get_block('1000');
  PERFORM hafah_endpoints.get_block_header('1000');
  PERFORM hafah_endpoints.get_block_range('1000', '1010');
  PERFORM hafah_endpoints.get_operations('1000', '1010');
  PERFORM hafah_endpoints.get_recent_trades(10);
  PERFORM hafah_endpoints.get_trade_history('1', '1000000', 10);
  PERFORM hafah_endpoints.get_version();

  RAISE NOTICE 'the REST endpoints run in a READ ONLY transaction';
END
$$;

ROLLBACK;
