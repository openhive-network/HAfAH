from json import dumps
from hafah.adapter import Db
from hafah.performance import perf

def handler(name, time, ahdb : 'account_history_db_connector' , *_, **__):
  ahdb.add_performance_record(name, time)

def format_array(array, type = 'INT'):
  if array is None:
    return f'ARRAY[]::{type}[]'
  return "ARRAY" + dumps(array) + f"::{type}[]" # if len(array) else f'ARRAY[]::{type}[]'

class account_history_db_connector:
  def __init__(self, db : Db) -> None:
    self._conn = db
    assert self._conn is not None
    self._schema = 'hafah_python'
    self.perf = {}

  def add_performance_record(self, name, time):
    self.perf[name] = time

  def _get_db(self):
    assert self._conn is not None
    return self._conn

  @perf(record_name='SQL', handler=handler)
  def _get_all(self, query, **kwargs):
    return self._get_db().query_all(query, **kwargs)

  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool, *, is_old_schema : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.get_ops_in_block_json( :block_num, :only_virt, :include_reversible, :is_old_schema )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible,
      is_old_schema=is_old_schema
    )[0]['get_ops_in_block_json']

  def get_transaction(self, trx_hash : bytes, include_reversible : bool, is_old_schema : bool ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_transaction_json( :trx_hash, :include_reversible, :is_old_schema )",
      trx_hash=trx_hash,
      include_reversible=include_reversible,
      is_old_schema=is_old_schema
    )[0]['get_transaction_json']


  def get_account_history(self, filter : list, account : str, start : int, limit : int, include_reversible : bool, *, is_old_schema : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.ah_get_account_history_json( {format_array(filter)}, :account, :start ::BIGINT, :limit, :include_reversible, :is_old_schema )",
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible,
      is_old_schema=is_old_schema
    )[0]['ah_get_account_history_json']

  def get_irreversible_block_num(self) -> int:
    result = self._get_all(f"SELECT hive.app_get_irreversible_block() as num")
    return result[0]['num']

  def get_operation_id_types(self):
    ''' for tests only '''
    return self._get_all("SELECT name, id FROM hive.operation_types")

  def get_virtual_op_offset(self) -> int:
    result = self._get_all("SELECT MIN(id) as id FROM hive.operation_types WHERE is_virtual=True")
    return result[0]['id']
