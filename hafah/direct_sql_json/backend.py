from hafah.backend import RECORD_NAME, handler, translate_filter
from hafah.exceptions import *
from hafah.objects import direct_sql_api
from hafah.performance import perf
from hafah.direct_sql_json.queries import account_history_db_connector

class account_history_impl:

  def __init__(self, ctx : dict, _ ):
    self.api = account_history_db_connector(ctx['db'])
    self.ctx = ctx
    self.repr = direct_sql_api

  def add_performance_record(self, name, time):
    self.ctx['perf'] = self.api.perf
    self.ctx['perf'][name] = (time - sum(self.api.perf.values()))

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool):
    return self.api.get_ops_in_block(block_num, only_virtual, include_reversible, is_old_schema=self.repr.is_old_schema())

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_transaction(self, trx_hash : str, include_reversible : bool ):
    return self.api.get_transaction( trx_hash.encode('ascii'), include_reversible, is_old_schema=self.repr.is_old_schema())

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_account_history(self, filter : int, account : str, start : int, limit : int, include_reversible : bool):
    return self.api.get_account_history(
      translate_filter( filter ),
      account,
      start,
      limit,
      include_reversible,
      is_old_schema=self.repr.is_old_schema()
    )
