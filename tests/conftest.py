from pytest import fixture, yield_fixture
import ah.api.endpoints as api_module

@yield_fixture(scope='session')
def api() -> api_module:
  # filled with: tests/data/records.sql
  psql_conn_str = "postgresql://postgres:pass@127.0.0.1:5432/hafah_testnet"
  singleton = api_module.backend_singleton(psql_conn_str)
  yield api_module
  singleton.finish()
