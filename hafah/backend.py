from typing import Union

from hafah.exceptions import *
from hafah.logger import get_logger
from hafah.performance import perf
from hafah.queries import account_history_db_connector

logger = get_logger(module_name='backend')

RANGE_POSITIVE_INT =  2**31-1
MAX_POSITIVE_INT = RANGE_POSITIVE_INT - 1
RANGEINT = 2**32
RECORD_NAME = 'backend'


def handler(name, time, ahi_instance : 'account_history_impl', *_, **__):
  ahi_instance.add_performance_record(name, time)

def translate_filter(input : int, *, offset : int = 0):
  if input:
    result = []
    for i in range(128):
      if input & (1 << i):
        result.append( i + offset )
    return result
  else:
    return None

def recurse_browse_for_title(data):
  if isinstance(data, (list, tuple)):
    for val in data:
      if recurse_browse_for_title(val):
        return True
  elif isinstance(data, dict):
    if 'title' in data and 'author' in data and data['author'] == 'kalipo':
      tit = data['title']
      logger.info(f"{'#'*12}, {[(c, ord(c)) for c in tit]}, `{tit}`")
      return True
    else:
      for val in data.values():
        if recurse_browse_for_title(val):
          return True
  return False

class account_history_impl:
  VIRTUAL_OP_ID_OFFSET = None

  def __init__(self, ctx : dict, is_legacy_style : bool):
    self.api = account_history_db_connector(ctx['db'])
    self.ctx = ctx
    self.is_legacy_style = is_legacy_style

    if account_history_impl.VIRTUAL_OP_ID_OFFSET is None:
      account_history_impl.VIRTUAL_OP_ID_OFFSET = self.api.get_virtual_op_offset()

  def add_performance_record(self, name, time):
    self.ctx['perf'] = self.api.perf
    self.ctx['perf'][name] = (time - sum(self.api.perf.values()))


  @perf(record_name=RECORD_NAME, handler=handler)
  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool):
    ops = self.api.get_ops_in_block(
      block_num,
      only_virtual,
      include_reversible,

      is_legacy_style=self.is_legacy_style
    )
    if block_num == 4910595:
      recurse_browse_for_title(ops)
    return ops


  @perf(record_name=RECORD_NAME, handler=handler)
  def get_transaction(self, trx_hash : str, include_reversible : bool):
    return self.api.get_transaction(
      trx_hash.encode('ascii'),
      include_reversible,

      is_legacy_style=self.is_legacy_style
    )

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_account_history(self, filter : int, account : str, start : int, limit : int, include_reversible : bool):
    return self.api.get_account_history(
      translate_filter( filter ),
      account,
      start,
      limit,
      include_reversible,

      is_legacy_style=self.is_legacy_style
    )

  @perf(record_name=RECORD_NAME, handler=handler)
  def enum_virtual_ops(self, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool = False):
    if account_history_impl.VIRTUAL_OP_ID_OFFSET is None and filter is not None:
      account_history_impl.VIRTUAL_OP_ID_OFFSET = self.api.get_virtual_op_offset()

    return self.api.enum_virtual_ops(
      translate_filter( filter, offset=account_history_impl.VIRTUAL_OP_ID_OFFSET ),
      block_range_begin,
      block_range_end,
      operation_begin,
      limit,
      include_reversible,
      group_by_block
    )
