from typing import Union
from hafah.backend import RANGE_POSITIVE_INT, RANGEINT
from hafah.backend import account_history_impl as standard_backend
from hafah.direct_sql_json.backend import account_history_impl as experimental_backend
from hafah.exceptions import *
from hafah.objects import account_history_api, condenser_api
from functools import partial
from distutils import util

MAX_BIGINT_POSTGRES = 9_223_372_036_854_775_807
ENUM_VIRTUAL_OPS_LIMIT = 150_000
DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000
BLOCK_WIDTH_LIMIT = 2 * DEFAULT_LIMIT

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

def backend(context, options) -> Union[standard_backend, experimental_backend]:
  return options['backend_type'](context, options['api_type'])

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

def get_ops_in_block(context : None, block_num = None, only_virtual = None, include_reversible = None, **kwargs : dict):
  try:
    block_num = 0 if block_num is None else int(block_num)
  except Exception:
    raise CustomUInt64ParserApiException()

  include_reversible  = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)
  only_virtual        = convert(only_virtual, False)

  return build_response( backend(context, kwargs).get_ops_in_block( block_num, only_virtual, include_reversible) )

def enum_virtual_ops(context : None, block_range_begin : str, block_range_end : str, operation_begin = None, limit = None, filter = None, include_reversible = None, group_by_block = None, **kwargs : dict):
  try:
    block_range_begin  = int(block_range_begin)
    block_range_end    = int(block_range_end)
    operation_begin    = 0       if operation_begin is None  else int(operation_begin)
    filter             = filter  if filter is None           else int(filter)
  except Exception:
    raise CustomUInt64ParserApiException()

  try:
    limit              = ENUM_VIRTUAL_OPS_LIMIT if limit is None            else int(limit)
  except Exception:
    raise CustomInt64ParserApiException()

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
  except Exception:
    raise CustomUInt64ParserApiException()

  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  filter = ( operation_filter_high << 64 ) | operation_filter_low
  start = start if start >= 0 else MAX_BIGINT_POSTGRES

  _limit = RANGE_POSITIVE_INT if limit == 0 else limit - 1
  limit = (RANGEINT + limit) if limit < 0 else limit

  if start < _limit:
    raise CustomAccountHistoryApiException()

  return build_response( backend(context, kwargs).get_account_history( filter, account, start, limit, include_reversible ) )

def build_methods(replace_standard_with_direct : bool):
  ACCOUNT_HISTORY_API = 'account_history_api'
  CONDENSER_API = 'condenser_api'
  DIRECT_SQL_AH = 'direct_sql_ah'
  DIRECT_SQL_CONDENSER = 'direct_sql'

  if replace_standard_with_direct:
    DIRECT_SQL_AH = ACCOUNT_HISTORY_API
    DIRECT_SQL_CONDENSER = CONDENSER_API

  def ah_method(foo):
    return (f'{ACCOUNT_HISTORY_API}.{foo.__name__}', partial(foo, api_type=account_history_api, backend_type=standard_backend))

  def ca_method(foo):
    return (f'{CONDENSER_API}.{foo.__name__}', partial(foo, api_type=condenser_api, backend_type=standard_backend))

  def dja_method(foo):
    return (f'{DIRECT_SQL_AH}.{foo.__name__}', partial(foo, api_type=account_history_api, backend_type=experimental_backend))

  def dj_method(foo):
    return (f'{DIRECT_SQL_CONDENSER}.{foo.__name__}', partial(foo, api_type=condenser_api, backend_type=experimental_backend))


  return dict([
    ah_method(get_ops_in_block ),
    ah_method(enum_virtual_ops ),
    ah_method(get_transaction ),
    ah_method(get_account_history ),

    ca_method(get_ops_in_block ),
    ca_method(get_transaction ),
    ca_method(get_account_history ),

# Theese has to be below

    dja_method(get_ops_in_block ),
    dja_method(enum_virtual_ops ),
    dja_method(get_transaction ),
    dja_method(get_account_history ),

    dj_method(get_ops_in_block ),
    dj_method(get_transaction ),
    dj_method(get_account_history )
  ])
