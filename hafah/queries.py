from json import dumps
from typing import Any

import sqlalchemy

from hafah.adapter import Db
from hafah.exceptions import InternalServerException, SQLExceptionWrapper
from hafah.logger import get_logger
from hafah.performance import perf

logger = get_logger(module_name='SQL')

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
    try:
      return self._get_db().query_all(query, **kwargs)
    except sqlalchemy.exc.InternalError as e:
      logger.debug(f'got expeced exception from SQL: {type(e).__name__} {e}')
      exception_raw = e.orig.args
      if len(exception_raw) == 0:
        raise SQLExceptionWrapper('error while processing exception')

      exception_raw = exception_raw[0].splitlines()
      if len(exception_raw) == 0:
        raise SQLExceptionWrapper('error while extracting exception message')

      raise SQLExceptionWrapper(exception_raw[0])
    except sqlalchemy.exc.SQLAlchemyError as e:
      logger.error(f'got unknown SQL exception: {type(e).__name__} {e}')
      raise SQLExceptionWrapper('unknown SQL exception')
    except Exception as e:
      logger.error(f'got unknown exception: {type(e).__name__} {e}')
      raise InternalServerException(str(e))



  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool, *, is_condenser_style : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.get_ops_in_block_json( :block_num, :only_virt, :include_reversible, :is_condenser_style )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible,
      is_condenser_style=is_condenser_style
    )[0]['get_ops_in_block_json']

  def get_transaction(self, trx_hash : bytes, include_reversible : bool, is_condenser_style : bool ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_transaction_json( :trx_hash, :include_reversible, :is_condenser_style )",
      trx_hash=trx_hash,
      include_reversible=include_reversible,
      is_condenser_style=is_condenser_style
    )[0]['get_transaction_json']

  def get_account_history(self, filter : list, account : str, start : int, limit : int, include_reversible : bool, *, is_condenser_style : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.ah_get_account_history_json( {format_array(filter)}, :account, :start ::BIGINT, :limit, :include_reversible, :is_condenser_style )",
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible,
      is_condenser_style=is_condenser_style
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

  def enum_virtual_ops(self, filter : list, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool):
    return self._get_all(
      f"SELECT * FROM {self._schema}.enum_virtual_ops_json( {format_array(filter)}, :block_range_begin, :block_range_end, :operation_begin, :limit, :include_reversible, :group_by_block )",
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit,
      include_reversible=include_reversible,
      group_by_block=group_by_block
    )[0]['enum_virtual_ops_json']
