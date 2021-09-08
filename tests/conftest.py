from pytest import fixture, yield_fixture
import ah.api.endpoints as api_module
# import ah
# import ah.eng_impl
# from ah import impl as eng_impl
from pytest import FixtureRequest

def pytest_addoption(parser):
  parser.addoption(
    '--psql-db-path', 
    # dest='psql', 
    type=str, 
    required=True, 
    help='connection string to postgres db ( ex. postgresql://postgres:pass@127.0.0.1:5432/hafah )'
  )

  parser.addoption(
    '--port',
    type=int,
    required=True,
    help='port number to use for performance tests'
  )

  parser.addoption(
    '--type',
    type=str,
    required=False,
    default='hafah',
    choices=['hafah', 'hived']
  )

@fixture(scope='session')
def port(request : FixtureRequest) -> int:
  return int(request.config.getoption('--port'))

@fixture(scope='session')
def psql(request : FixtureRequest) -> str:
  return request.config.getoption("--psql-db-path")

@fixture(scope='session')
def run_type(request : FixtureRequest) -> str:
  return request.config.getoption("--type")

@yield_fixture(scope='session')
def server(run_type, port, psql) -> str:
  # if run_type == 'hafah':
    # return f'127.0.0.1:{port}'
  # else:
  return f'http://127.0.0.1:{port}'


@yield_fixture(scope='session')
def api(psql) -> api_module:
  # filled with: tests/data/records.sql
  # psql_conn_str = "postgresql://postgres:pass@127.0.0.1:5432/hafah_testnet"
  singleton = api_module.backend_singleton(psql)
  yield api_module
  singleton.finish()
