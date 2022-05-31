# -*- coding: utf-8 -*-
from distutils import util
from functools import partial

from hafah.backend import RANGEINT
from hafah.backend import account_history_impl as standard_backend
from hafah.exceptions import *

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

def backend(context, options) -> standard_backend:
  return standard_backend(context, options['is_legacy_style'])

def get_ops_in_block(context : None, block_num = None, only_virtual = None, include_reversible = None, **kwargs : dict):
  try:
    block_num = 0 if block_num is None else int(block_num)
  except Exception:
    raise CustomUInt64ParserApiException()

  include_reversible  = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)
  only_virtual        = convert(only_virtual, False)

  return backend(context, kwargs).get_ops_in_block( block_num, only_virtual, include_reversible)

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

  return backend(context, kwargs).enum_virtual_ops( filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible, group_by_block )

def get_transaction(context : None, id : str, include_reversible = None, **kwargs : dict):
  if len(id) != 40:
    raise CustomInvalidTransactionHashLength(id)

  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  return backend(context, kwargs).get_transaction( id, include_reversible )

def get_account_history(context : None, account : str, start = None, limit = None, operation_filter_low = None, operation_filter_high = None, include_reversible = None, **kwargs : dict):
  try:
    start                  = -1            if start is None                  else int(start)
    limit                  = DEFAULT_LIMIT if limit is None                  else int(limit)
    operation_filter_low   = None          if operation_filter_low is None   else int(operation_filter_low)
    operation_filter_high  = None          if operation_filter_high is None  else int(operation_filter_high)
  except Exception:
    raise CustomUInt64ParserApiException()

  include_reversible = convert(include_reversible, DEFAULT_INCLUDE_IRREVERSIBLE)

  start = start if start >= 0 else MAX_BIGINT_POSTGRES
  limit = (RANGEINT + limit) if limit < 0 else limit

  return backend(context, kwargs).get_account_history( operation_filter_low, operation_filter_high, account, start, limit, include_reversible )

def build_methods():
  ACCOUNT_HISTORY_API = 'account_history_api'
  CONDENSER_API = 'condenser_api'

  def ah_method(foo):
    return (f'{ACCOUNT_HISTORY_API}.{foo.__name__}', partial(foo, is_legacy_style=False))

  def ca_method(foo):
    return (f'{CONDENSER_API}.{foo.__name__}', partial(foo, is_legacy_style=True))

  return dict([
    ah_method(get_ops_in_block),
    ah_method(enum_virtual_ops),
    ah_method(get_transaction),
    ah_method(get_account_history),

    ca_method(get_ops_in_block),
    ca_method(get_transaction),
    ca_method(get_account_history)
  ])
