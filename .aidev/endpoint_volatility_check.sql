-- Every function in hafah_endpoints, the REST endpoints and the JSON-RPC
-- dispatcher alike, is STABLE or IMMUTABLE, so PostgREST runs its POST calls
-- (the rewriter forwards REST GETs as POSTs; JSON-RPC clients always POST) in
-- a READ ONLY transaction, as it does for VOLATILE functions only on GET.
-- Then the REST endpoints whose volatility was once missing, and every method
-- home(json) routes, are called inside a READ ONLY transaction on the shared
-- HAF (the chain to block 5000000).
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
    AND p.provolatile = 'v';

  IF _volatile IS NOT NULL THEN
    RAISE EXCEPTION 'hafah_endpoints functions declared VOLATILE: %', _volatile;
  END IF;

  RAISE NOTICE 'every function in hafah_endpoints is STABLE or IMMUTABLE';
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

DO $$
DECLARE
  _known_trx CONSTANT TEXT = '9e19c9082fea1a87f9dede8c9854a243185402b8';
  _call RECORD;
  _response JSONB;
BEGIN
  FOR _call IN
    SELECT * FROM (VALUES
      ('hive_api.get_version', '{}'::JSON),
      ('account_history_api.get_ops_in_block', '{"block_num": 4000000}'),
      ('account_history_api.enum_virtual_ops', '{"block_range_begin": 4000000, "block_range_end": 4000010}'),
      ('account_history_api.get_transaction', json_build_object('id', _known_trx)),
      ('account_history_api.get_account_history', '{"account": "steemit", "start": -1, "limit": 10}'),
      ('condenser_api.get_ops_in_block', '[4000000, false]'),
      ('condenser_api.get_transaction', json_build_array(_known_trx)),
      ('condenser_api.get_account_history', '["steemit", -1, 10]'),
      ('block_api.get_block', '{"block_num": 1}'),
      ('block_api.get_block_header', '{"block_num": 1}'),
      ('block_api.get_block_range', '{"starting_block_num": 4000000, "count": 5}')
    ) AS calls(method, params)
  LOOP
    _response = hafah_endpoints.home(json_build_object('jsonrpc', '2.0', 'id', 1, 'method', _call.method, 'params', _call.params));
    IF _response ? 'error' OR NOT _response ? 'result' THEN
      RAISE EXCEPTION 'JSON-RPC % failed in a READ ONLY transaction: %', _call.method, _response;
    END IF;
  END LOOP;

  _response = hafah_endpoints.home('{"jsonrpc": "2.0", "id": 1, "method": "hive_api.get_version", "params": {}}');
  IF _response->'result' IS DISTINCT FROM jsonb_build_object(
       'app_name', 'PostgRESTHAfAH',
       'commit', (SELECT git_hash FROM hafah_backend.version LIMIT 1)) THEN
    RAISE EXCEPTION 'JSON-RPC hive_api.get_version answered %', _response;
  END IF;

  _response = hafah_endpoints.home('{"jsonrpc": "2.0", "id": 1, "method": "account_history_api.no_such_method", "params": {}}');
  IF (_response->'error'->>'code')::INT IS DISTINCT FROM -32601 THEN
    RAISE EXCEPTION 'an unknown JSON-RPC method answered %', _response;
  END IF;

  PERFORM hafah_endpoints.get_ops_in_block('{"block_num": 4000000}'::JSON);
  PERFORM hafah_endpoints.enum_virtual_ops('{"block_range_begin": 4000000, "block_range_end": 4000010}'::JSON);
  PERFORM hafah_endpoints.get_account_history('{"account": "steemit", "start": -1, "limit": 10}'::JSON);

  RAISE NOTICE 'every JSON-RPC method runs in a READ ONLY transaction';
END
$$;

ROLLBACK;
