from ah.db.objects import account_history, operation, ops_in_block, transaction, virtual_ops
from ah.db.queries2 import account_history_db_connector
from ah.utils.performance import perf

from jsonrpcserver.exceptions import ApiError

MAXINT =  2**31-1

def extractor(*args, **kwargs):
  return args[0][1]['id']

class CustomTransactionApiException(ApiError):
  def __init__(self, trx_hash):
    #because type of `trx_hash` is `ripemd160`
    trx_hash_size = 40

    if len(trx_hash) < trx_hash_size:
      for i in range(trx_hash_size - len(trx_hash)):
        trx_hash += '0'
    super().__init__("Assert Exception:false: Unknown Transaction {}".format(trx_hash), -32003)

class CustomAccountHistoryApiException(ApiError):
  def __init__(self):
    super().__init__("Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)", -32003)

class account_history_impl:

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

  @perf(extract_identifier=extractor, record_name='backend')
  def get_ops_in_block( self, args, block_num : int, only_virtual : bool, include_reversible : bool) -> ops_in_block:
    api = account_history_db_connector(args)
    return ops_in_block( block_num, api.get_ops_in_block(block_num, only_virtual, include_reversible) )

  @perf(extract_identifier=extractor, record_name='backend')
  def get_transaction(self, args, trx_hash : str, include_reversible : bool ) -> transaction:
    api = account_history_db_connector(args)

    transaction_basic_info = api.get_transaction( trx_hash.encode('ascii'), include_reversible )

    if len(transaction_basic_info) == 0:
      raise CustomTransactionApiException(trx_hash)
    else:
      _info = transaction_basic_info[0]
      if len(_info) > 0 and _info[0] is None:
        raise CustomTransactionApiException(trx_hash)
      else:
        transaction_basic_info = dict(_info)

    operations = api.get_ops_in_transaction( transaction_basic_info['_block_num'], transaction_basic_info['_trx_in_block'] )

    transaction_basic_info['_signature'] = [ transaction_basic_info['_signature'] ]
    if transaction_basic_info['_multisig_number'] >= 1:
      additional_signatures = api.get_multi_signatures_in_transaction( trx_hash )
      transaction_basic_info['_signature'].extend( [x[0] for x in additional_signatures] )

    transaction_basic_info['_value'] = [ operation( op[0] ) for op in operations ]

    return transaction(trx_hash, transaction_basic_info)


  @perf(extract_identifier=extractor, record_name='backend')
  def enum_virtual_ops(self, args, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool = False ) -> virtual_ops:
    api = account_history_db_connector(args)
    if account_history_impl.VIRTUAL_OP_ID_OFFSET is None and filter is not None:
      account_history_impl.VIRTUAL_OP_ID_OFFSET = api.get_virtual_op_offset()

    _result = virtual_ops(
      api.get_irreversible_block_num() if group_by_block else None,
      api.enum_virtual_ops(
        self.__translate_filter( filter, lambda x : x + account_history_impl.VIRTUAL_OP_ID_OFFSET ),
        block_range_begin,
        block_range_end,
        operation_begin,
        limit,
        include_reversible
      )
    )

    _new_data_required, _last_block_num, _last_id = _result.get_pagination_data(block_range_end, limit)

    if _new_data_required:
      _next_block_range_begin, _next_operation_begin = api.get_pagination_data(_last_block_num, _last_id, block_range_end)
      _result.update_pagination_data(_next_block_range_begin, _next_operation_begin)
  
    return _result

  @perf(extract_identifier=extractor, record_name='backend')
  def get_account_history(self, args, filter : int, account : str, start : int, limit : int, include_reversible : bool) -> account_history:
    _limit = MAXINT if limit == 0 else limit - 1
    if start >= _limit:
      api = account_history_db_connector(args)
      return account_history(
          api.get_account_history(
          self.__translate_filter( filter ),
          account,
          start,
          limit,
          include_reversible
        )
      )
    else:
      raise CustomAccountHistoryApiException()