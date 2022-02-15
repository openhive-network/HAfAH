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

def convert(val):
  try:
    if val is None:
      return DEFAULT_INCLUDE_IRREVERSIBLE

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

def get_ops_in_block(context : None, block_num : int = 0, only_virtual : bool = False, include_reversible = None, **kwargs : dict):
  include_reversible = convert(include_reversible)
  return build_response( backend(context, kwargs).get_ops_in_block( block_num, only_virtual, include_reversible) )

def enum_virtual_ops(context : None, block_range_begin : int, block_range_end : int, operation_begin = "0", limit = str(MAX_POSITIVE_INT), filter : int = None, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, group_by_block : bool = False, **kwargs : dict):
  try:
    _block_range_begin  = int(block_range_begin)
    _block_range_end    = int(block_range_end)
    _operation_begin    = int(operation_begin)
    _limit              = int(limit)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  assert _block_range_end > _block_range_begin, 'block range must be upward'

  include_reversible = convert(include_reversible)
  return build_response( backend(context, kwargs).enum_virtual_ops( filter, _block_range_begin, _block_range_end, _operation_begin, _limit, include_reversible, group_by_block ) )

def get_transaction(context : None, id : str, include_reversible = None, **kwargs : dict):
  include_reversible = convert(include_reversible)
  return build_response( backend(context, kwargs).get_transaction( id, include_reversible ) )

def get_account_history(context : None, account : str, start : int = "-1", limit = str(DEFAULT_LIMIT), operation_filter_low = "0", operation_filter_high = "0", include_reversible = None, **kwargs : dict):
  _operation_filter_low   = None
  _operation_filter_high  = None
  _start                  = None
  _limit                  = None

  try:
    _start                  = int(start)
    _limit                  = int(limit)
    _operation_filter_low   = int(operation_filter_low)
    _operation_filter_high  = int(operation_filter_high)
  except Exception as ex:
    raise CustomUInt64ParserApiException()

  include_reversible = convert(include_reversible)

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
