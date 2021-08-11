from pytest import fixture
from ah.db.backend import account_history_impl


@fixture(scope='session')
def api() -> account_history_impl:
  psql_conn_str = "postgresql://postgres:pass@127.0.0.1:5432/hafah_testnet"
  return account_history_impl( psql_conn_str )