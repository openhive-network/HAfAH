from ah.db.backend import account_history_impl
from ah.db.objects import account_history_api, condenser_api
from ah.api.validation import verify_types, convert_maybe, require_unsigned, max_value
from functools import partial

MAX_INT_POSTGRES = 2_147_483_646
MAX_BIGINT_POSTGRES = 9_223_372_036_854_775_807
DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000
limit_contraint = max_value(DEFAULT_LIMIT)

def backend(context, options):
  return account_history_impl(context, options['api_type'])

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

@verify_types(convert_maybe, block_num=require_unsigned)
def get_ops_in_block(block_num : int = 0, only_virtual : bool = False, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, context : None = None, **kwargs : dict):
  return build_response( backend(context, kwargs).get_ops_in_block( block_num, only_virtual, include_reversible) )

@verify_types(convert_maybe, block_range_begin=require_unsigned, block_range_end=require_unsigned, limit=[require_unsigned])
def enum_virtual_ops(block_range_begin : int, block_range_end : int, operation_begin : int = 0, limit : int = MAX_INT_POSTGRES, filter : int = None, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, group_by_block : bool = False, context : None = None, **kwargs : dict):
  assert block_range_end > block_range_begin, 'block range must be upward'
  return build_response( backend(context, kwargs).enum_virtual_ops( filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible, group_by_block ) )

@verify_types(convert_maybe)
def get_transaction(id : str, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, context : None = None, **kwargs : dict):
  return build_response( backend(context, kwargs).get_transaction( id, include_reversible ) )

@verify_types(convert_maybe, limit=(require_unsigned, limit_contraint))
def get_account_history(account : str, start : int = -1, limit : int = DEFAULT_LIMIT, operation_filter_low : int = 0, operation_filter_high : int = 0, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, context : None = None, **kwargs : dict):
  filter = ( operation_filter_high << 64 ) | operation_filter_low
  start = start if start >= 0 else MAX_BIGINT_POSTGRES
  return build_response( backend(context, kwargs).get_account_history( filter, account, start, limit, include_reversible ) )

def build_methods():
  def ah_method( name, foo ):
    return (f'account_history_api.{name}', partial(foo, api_type=account_history_api))

  def ca_method(name, foo ):
    return (f'condenser_api.{name}', partial(foo, api_type=condenser_api))

  return dict([
    ah_method( 'get_ops_in_block', get_ops_in_block ),
    ah_method( 'enum_virtual_ops', enum_virtual_ops ),
    ah_method( 'get_transaction', get_transaction ),
    ah_method( 'get_account_history', get_account_history ),

    ca_method( 'get_ops_in_block', get_ops_in_block ),
    ca_method( 'enum_virtual_ops', enum_virtual_ops ),
    ca_method( 'get_transaction', get_transaction ),
    ca_method( 'get_account_history', get_account_history )
  ])
