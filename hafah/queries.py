from typing import Any

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
    if name in self.perf:
      self.perf[name] += time
    else:
      self.perf[name] = time

  def _get_db(self):
    assert self._conn is not None
    return self._conn

  @perf(record_name='SQL', handler=handler)
  def _get_all(self, query, **kwargs):
    return self._get_db().query_all(query, **kwargs)

  def get_multi_signatures_in_transaction(self, trx_hash : bytes ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_multi_signatures_in_transaction( :trx_hash )",
      trx_hash=trx_hash
    )

  def get_ops_in_transaction(self, block_num : int, trx_in_block : int, *, is_old_schema : bool ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_ops_in_transaction( :block_num, :trx_in_block, :is_old_schema )",
      block_num=block_num,
      trx_in_block=trx_in_block,
      is_old_schema=is_old_schema
    )

  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool, *, is_old_schema : bool):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_ops_in_block( :block_num,  :only_virt, :include_reversible, :is_old_schema )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible,
      is_old_schema=is_old_schema
    )

  def get_transaction(self, trx_hash : bytes, include_reversible : bool ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_transaction( :trx_hash, :include_reversible )",
      trx_hash=trx_hash,
      include_reversible=include_reversible
    )

  def enum_virtual_ops(self, filter : list, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool):
    return self._get_all(
      f"SELECT * FROM {self._schema}.enum_virtual_ops( {format_array(filter)}, :block_range_begin, :block_range_end, :operation_begin, :limit, :include_reversible )",
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit,
      include_reversible=include_reversible
    )

  def get_account_history(self, filter : list, account : str, start : int, limit : int, include_reversible : bool, *, is_old_schema : bool):
    return self._get_all(
      f"SELECT * FROM {self._schema}.ah_get_account_history( {format_array(filter)}, :account, :start ::BIGINT, :limit, :include_reversible, :is_old_schema )",
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible,
      is_old_schema=is_old_schema
    )

  def get_irreversible_block_num(self) -> int:
    result = self._get_all(f"SELECT hive.app_get_irreversible_block() as num")
    return result[0]['num']

  def get_operation_id_types(self):
    ''' for tests only '''
    return self._get_all("SELECT name, id FROM hive.operation_types")

  def get_virtual_op_offset(self) -> int:
    result = self._get_all("SELECT MIN(id) as id FROM hive.operation_types WHERE is_virtual=True")
    return result[0]['id']

  def get_pagination_data(self, last_block_num, last_id, block_range_end):
    _query = '''
                SELECT o.block_num, o.id
                FROM hive.operations o
                JOIN hive.operation_types ot ON o.op_type_id = ot.id
                WHERE ot.is_virtual=true AND o.block_num>={} AND o.id>{} ORDER BY o.block_num, o.id LIMIT 1
            '''
    _result = self._get_all(_query.format(last_block_num, last_id))
    if len(_result) == 0:
      return 0, 0
    else:
      _record = _result[0]
      _new_block_num = _record['block_num']
      _new_id = _record['id']
      if _new_block_num >= block_range_end:
        _new_id = 0
      return _new_block_num, _new_id
