from pytest import fixture, yield_fixture
import ah.api.endpoints as api_module

def pytest_addoption(parser):
  parser.addoption(
    '--psql-db-path', 
    # dest='psql', 
    type=str, 
    required=True, 
    help='connection string to postgres db ( ex. postgresql://postgres:pass@127.0.0.1:5432/hafah )'
  )

from pytest import FixtureRequest
@yield_fixture(scope='session')
def api(request : FixtureRequest ) -> api_module:
  # filled with: tests/data/records.sql
  # psql_conn_str = "postgresql://postgres:pass@127.0.0.1:5432/hafah_testnet"
  psql_conn_str = request.config.getoption("--psql-db-path")
  singleton = api_module.backend_singleton(psql_conn_str)
  yield api_module
  singleton.finish()
