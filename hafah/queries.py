# -*- coding: utf-8 -*-
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

class account_history_db_connector:
  def __init__(self, db : Db) -> None:
    self._conn = db
    assert self._conn is not None
    self._schema = 'hafah_python'
    self.perf = {}
    self.last_query = str()

  def add_performance_record(self, name, time):
    if name in self.perf:
      self.perf[name] += time
    else:
      self.perf[name] = time

  def _get_db(self):
    assert self._conn is not None
    return self._conn

  @perf(record_name='1.SQL', handler=handler)
  def _get_all(self, query, **kwargs):
    try:
      query, result = self._get_db().query_all(query, **kwargs)
      self.last_query = query
      return result
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



  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool, *, is_legacy_style : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.get_ops_in_block_json( :block_num, :only_virt, :include_reversible, :is_legacy_style )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible,
      is_legacy_style=is_legacy_style
    )[0]['get_ops_in_block_json']

  def get_transaction(self, trx_hash : bytes, include_reversible : bool, is_legacy_style : bool ):
    return self._get_all(
      f"SELECT * FROM {self._schema}.get_transaction_json( :trx_hash, :include_reversible, :is_legacy_style )",
      trx_hash=trx_hash,
      include_reversible=include_reversible,
      is_legacy_style=is_legacy_style
    )[0]['get_transaction_json']

  def get_account_history(self, filter_low : int, filter_high : int, account : str, start : int, limit : int, include_reversible : bool, *, is_legacy_style : bool):
    return self._get_all(
      f"SELECT * FROM hafah_python.ah_get_account_history_json( :filter_low, :filter_high, :account, :start ::BIGINT, :limit, :include_reversible, :is_legacy_style )",
      filter_low=filter_low,
      filter_high=filter_high,
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible,
      is_legacy_style=is_legacy_style
    )[0]['ah_get_account_history_json']

  def enum_virtual_ops(self, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool):
    return self._get_all(
      f"SELECT * FROM {self._schema}.enum_virtual_ops_json( :filter, :block_range_begin, :block_range_end, :operation_begin, :limit, :include_reversible, :group_by_block )",
      filter=filter,
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit,
      include_reversible=include_reversible,
      group_by_block=group_by_block
    )[0]['enum_virtual_ops_json']
