from typing import Union
from hafah.objects import account_history_api, condenser_api
from hafah.queries import account_history_db_connector
from hafah.performance import perf

from jsonrpcserver.exceptions import ApiError

JSON_RPC_SERVER_ERROR       = -32000
JSON_RPC_ERROR_DURING_CALL  = -32003

RANGE_POSITIVE_INT =  2**31-1
MAX_POSITIVE_INT = RANGE_POSITIVE_INT - 1
RANGEINT = 2**32
RECORD_NAME = 'backend'

def handler(name, time, ahi_instance : 'account_history_impl', *_, **__):
  ahi_instance.add_performance_record(name, time)

class SQLExceptionWrapper(ApiError):
  def __init__(self, msg):
    super().__init__(msg, JSON_RPC_ERROR_DURING_CALL)

class CustomTransactionApiException(ApiError):
  def __init__(self, trx_hash):
    #because type of `trx_hash` is `ripemd160`
    trx_hash_size = 40

    if len(trx_hash) < trx_hash_size:
      for i in range(trx_hash_size - len(trx_hash)):
        trx_hash += '0'
    super().__init__("Assert Exception:false: Unknown Transaction {}".format(trx_hash), JSON_RPC_ERROR_DURING_CALL)

class CustomAccountHistoryApiException(ApiError):
  def __init__(self):
    super().__init__("Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)", JSON_RPC_ERROR_DURING_CALL)

class CustomUInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse uint64_t", JSON_RPC_SERVER_ERROR)

class CustomInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse int64_t", JSON_RPC_SERVER_ERROR)

class CustomBoolParserApiException(ApiError):
  def __init__(self):
    super().__init__("Bad Cast:Cannot convert string to bool (only \"true\" or \"false\" can be converted)", JSON_RPC_SERVER_ERROR)

class account_history_impl:

  def __init__(self, ctx : dict, repr : Union[account_history_api, condenser_api]):
    self.api = account_history_db_connector(ctx['db'])
    self.ctx = ctx
    self.repr = repr

  def add_performance_record(self, name, time):
    self.ctx['perf'] = self.api.perf
    self.ctx['perf'][name] = (time - sum(self.api.perf.values()))

  VIRTUAL_OP_ID_OFFSET = None

  def __translate_filter(self, input : int, transform = lambda x : x):
    if input:
      result = []
      for i in range(128):
        if input & (1 << i):
          result.append( transform(i) )
      return result
    else:
      return None

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool):
    return self.repr.get_ops_in_block( block_num, self.api.get_ops_in_block(block_num, only_virtual, include_reversible, is_old_schema=self.repr.is_old_schema()) )

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_transaction(self, trx_hash : str, include_reversible : bool ):
    transaction_basic_info = self.api.get_transaction( trx_hash.encode('ascii'), include_reversible )

    if len(transaction_basic_info) == 0:
      raise CustomTransactionApiException(trx_hash)
    else:
      _info = transaction_basic_info[0]
      if len(_info) > 0 and _info[0] is None:
        raise CustomTransactionApiException(trx_hash)
      else:
        transaction_basic_info = dict(_info)

    operations = self.api.get_ops_in_transaction( transaction_basic_info['_block_num'], transaction_basic_info['_trx_in_block'], is_old_schema=self.repr.is_old_schema())

    transaction_basic_info['_signature'] = [ transaction_basic_info['_signature'] ]
    if transaction_basic_info['_multisig_number'] >= 1:
      additional_signatures = self.api.get_multi_signatures_in_transaction( trx_hash )
      transaction_basic_info['_signature'].extend( [x[0] for x in additional_signatures] )

    transaction_basic_info['_value'] = [ self.repr.operation( op[0] ) for op in operations ]

    return self.repr.get_transaction(trx_hash, transaction_basic_info)


  @perf(record_name=RECORD_NAME, handler=handler)
  def enum_virtual_ops(self, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool = False ):
    if account_history_impl.VIRTUAL_OP_ID_OFFSET is None and filter is not None:
      account_history_impl.VIRTUAL_OP_ID_OFFSET = self.api.get_virtual_op_offset()

    _result = self.repr.enum_virtual_ops(
      self.api.get_irreversible_block_num() if group_by_block else None,
      self.api.enum_virtual_ops(
        self.__translate_filter( filter, lambda x : x + account_history_impl.VIRTUAL_OP_ID_OFFSET ),
        block_range_begin,
        block_range_end,
        operation_begin,
        limit,
        include_reversible
      ),
      block_range_end,
      limit,
      self.api.get_pagination_data
    )
    return _result

  @perf(record_name=RECORD_NAME, handler=handler)
  def get_account_history(self, filter : int, account : str, start : int, limit : int, include_reversible : bool):
    limit = (RANGEINT + limit) if limit < 0 else limit

    return self.repr.get_account_history(
        self.api.get_account_history(
        self.__translate_filter( filter ),
        account,
        start,
        limit,
        include_reversible,
        is_old_schema=self.repr.is_old_schema()
      )
    )
