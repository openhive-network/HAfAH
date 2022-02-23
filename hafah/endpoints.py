from typing import Union
from hafah.backend import CustomBlocksRangeTooWideException, account_history_impl, MAX_POSITIVE_INT, CustomUInt64ParserApiException, CustomBoolParserApiException, CustomInvalidBlocksRangeException
from hafah.objects import account_history_api, condenser_api
# from hafah.validation import verify_types, convert_maybe, require_unsigned, max_value
from functools import partial
from distutils import util

from hafah.validation import convert_maybe, process_types, str2bool, uint, unsigned

MAX_BIGINT_POSTGRES = 9_223_372_036_854_775_807
DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000
BLOCK_WIDTH_LIMIT = 2 * DEFAULT_LIMIT

sint = Union[int, str] # int, if str convert to int

def convert(val, default_value):
  try:
    if val is None:
      return default_value

    invalid_val = False
    if isinstance(val, str):
      if(val == "true" or val == "false"):#old code from AH doesn't allow f.e. `True` value
        return bool(util.strtobool(val))
      else:
        invalid_val = True
    elif isinstance(val, int):
      return bool(val)
  except Exception as ex:
    raise CustomBoolParserApiException()

  if invalid_val:
    raise CustomBoolParserApiException()
  else:
    return val

def backend(context, api_type):
  return account_history_impl(context, api_type)

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

@process_types(convert_maybe)
def get_ops_in_block(context, api_type, *, block_num : int = 0, only_virtual : bool = False, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  print(only_virtual, flush=True)
  return build_response( backend(context, api_type).get_ops_in_block( block_num, only_virtual, include_reversible) )

def enum_virtual_ops(context : None, block_range_begin : str, block_range_end : str, operation_begin = None, limit = None, filter = None, include_reversible = None, group_by_block = None, **kwargs : dict):
  try:
    block_range_begin  = int(block_range_begin)
    block_range_end    = int(block_range_end)
    operation_begin    = 0                 if operation_begin is None  else int(operation_begin)
    limit              = MAX_POSITIVE_INT  if limit is None            else int(limit)
    filter             = filter            if filter is None           else int(filter)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  if block_range_end <= block_range_begin:
    raise CustomInvalidBlocksRangeException()

  if block_range_end - block_range_begin > BLOCK_WIDTH_LIMIT:
    raise CustomBlocksRangeTooWideException()

  include_reversible  = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)
  group_by_block      = convert(group_by_block, False)

  return build_response( backend(context, kwargs).enum_virtual_ops( filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible, group_by_block ) )

def get_transaction(context : None, id : str, include_reversible = None, **kwargs : dict):
  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  return build_response( backend(context, kwargs).get_transaction( id, include_reversible ) )

def get_account_history(context : None, account : str, start = None, limit = None, operation_filter_low = None, operation_filter_high = None, include_reversible = None, **kwargs : dict):
  try:
    start                  = -1            if start is None                  else int(start)
    limit                  = DEFAULT_LIMIT if limit is None                  else int(limit)
    operation_filter_low   = 0             if operation_filter_low is None   else int(operation_filter_low)
    operation_filter_high  = 0             if operation_filter_high is None  else int(operation_filter_high)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  filter = ( operation_filter_high << 64 ) | operation_filter_low
  start = start if start >= 0 else MAX_BIGINT_POSTGRES

  return build_response( backend(context, kwargs).get_account_history( filter, account, start, limit, include_reversible ) )

@process_types(a=str2bool, b=unsigned(uint.uint32_t))
def ping(ctx, *, a : bool, b : sint = 1 , **_):
  print(ctx)
  print(a)
  print(b)
  print(_)
  print('#####', flush=True)
  return dict(done=1)

def build_methods():
  def ah_method( name, foo ):
    return (f'account_history_api.{name}', partial(foo, account_history_api))

  def ca_method(name, foo ):
    return (f'condenser_api.{name}', partial(foo, condenser_api))

  return dict([
    ("ping", ping),

    ah_method( 'get_ops_in_block', get_ops_in_block ),
    ah_method( 'enum_virtual_ops', enum_virtual_ops ),
    ah_method( 'get_transaction', get_transaction ),
    ah_method( 'get_account_history', get_account_history ),

    ca_method( 'get_ops_in_block', get_ops_in_block ),
    ca_method( 'enum_virtual_ops', enum_virtual_ops ),
    ca_method( 'get_transaction', get_transaction ),
    ca_method( 'get_account_history', get_account_history )
  ])
