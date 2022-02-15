from ah.db.backend import account_history_impl, MAX_POSITIVE_INT
from ah.db.objects import account_history_api, condenser_api
from ah.api.validation import verify_types, convert_maybe, require_unsigned, max_value
from functools import partial
from jsonrpcserver.exceptions import ApiError
from distutils import util

JSON_RPC_SERVER_ERROR = -32000

MAX_BIGINT_POSTGRES = 9_223_372_036_854_775_807
DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000
limit_contraint = max_value(DEFAULT_LIMIT)

class CustomUInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse uint64_t", JSON_RPC_SERVER_ERROR)

class CustomBoolParserApiException(ApiError):
  def __init__(self):
    super().__init__("Bad Cast:Cannot convert string to bool (only \"true\" or \"false\" can be converted)", JSON_RPC_SERVER_ERROR)

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

def backend(context, options):
  return account_history_impl(context, options['api_type'])

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

def get_ops_in_block(context : None, block_num = None, only_virtual = None, include_reversible = None, **kwargs : dict):
  try:
    block_num = 0 if block_num is None else int(block_num)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  include_reversible  = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)
  only_virtual        = convert(only_virtual, False)

  return build_response( backend(context, kwargs).get_ops_in_block( block_num, only_virtual, include_reversible) )

def enum_virtual_ops(context : None, block_range_begin : str, block_range_end : str, operation_begin = None, limit = None, filter = None, include_reversible = None, group_by_block = None, **kwargs : dict):
  try:
    _block_range_begin  = int(block_range_begin)
    _block_range_end    = int(block_range_end)
    _operation_begin    = 0                 if operation_begin is None  else int(operation_begin)
    _limit              = MAX_POSITIVE_INT  if limit is None            else int(limit)
    _filter             = filter            if filter is None           else int(filter)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  assert _block_range_end > _block_range_begin, 'block range must be upward'

  include_reversible  = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)
  group_by_block      = convert(group_by_block, False)

  return build_response( backend(context, kwargs).enum_virtual_ops( _filter, _block_range_begin, _block_range_end, _operation_begin, _limit, include_reversible, group_by_block ) )

def get_transaction(context : None, id : str, include_reversible = None, **kwargs : dict):
  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  return build_response( backend(context, kwargs).get_transaction( id, include_reversible ) )

def get_account_history(context : None, account : str, start = None, limit = None, operation_filter_low = None, operation_filter_high = None, include_reversible = None, **kwargs : dict):
  try:
    _start                  = -1            if start is None                  else int(start)
    _limit                  = DEFAULT_LIMIT if limit is None                  else int(limit)
    _operation_filter_low   = 0             if operation_filter_low is None   else int(operation_filter_low)
    _operation_filter_high  = 0             if operation_filter_high is None  else int(operation_filter_high)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  filter = ( _operation_filter_high << 64 ) | _operation_filter_low
  _start = _start if _start >= 0 else MAX_BIGINT_POSTGRES

  return build_response( backend(context, kwargs).get_account_history( filter, account, _start, _limit, include_reversible ) )

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
