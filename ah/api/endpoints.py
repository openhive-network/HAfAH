from ah.db.backend import account_history_impl
from ah.api.validation import verify_types, convert_maybe, require_unsigned, max_value

DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000
limit_contraint = max_value(DEFAULT_LIMIT)

def backend():
  return account_history_impl()

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

@verify_types(convert_maybe, block_num=require_unsigned)
async def get_ops_in_block(*, args, block_num : int, only_virtual : bool, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  return build_response( await backend().get_ops_in_block( args, block_num, only_virtual, include_reversible) )

@verify_types(convert_maybe, block_range_begin=require_unsigned, block_range_end=require_unsigned, limit=[require_unsigned, limit_contraint])
async def enum_virtual_ops(*, args, block_range_begin : int, block_range_end : int, operation_begin : int = 0, limit : int = DEFAULT_LIMIT, filter : int = None, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, group_by_block : bool = False, **kwargs):
  assert block_range_end > block_range_begin, 'block range must be upward'
  return build_response( await backend().enum_virtual_ops( args, filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible, group_by_block ) )

@verify_types(convert_maybe)
async def get_transaction(*, args, id : str, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  return build_response( await backend().get_transaction( args, id, include_reversible ) )

@verify_types(convert_maybe, limit=(require_unsigned, limit_contraint))
async def get_account_history(*, args, account : str, start : int, limit : int = DEFAULT_LIMIT, operation_filter_low : int = 0, operation_filter_high : int = 0, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  filter = ( operation_filter_high << 32 ) | operation_filter_low
  start = start if start >= 0 else 9223372036854775807 # max bigint in psql
  return build_response( await backend().get_account_history( args, filter, account, start, limit, include_reversible ) )

def build_methods():
  def method( name, foo ):
    return (f'account_history_api.{name}', foo)

  methods = dict([
    method( 'get_ops_in_block', get_ops_in_block ),
    method( 'enum_virtual_ops', enum_virtual_ops ),
    method( 'get_transaction', get_transaction ),
    method( 'get_account_history', get_account_history )
  ])

  return methods
