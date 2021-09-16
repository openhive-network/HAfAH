from ah.db.backend import account_history_impl

DEFAULT_INCLUDE_IRREVERSIBLE = False
DEFAULT_LIMIT = 1_000

def backend():
  return account_history_impl()

def build_response( obj ):
  '''proxy method, currently useless'''
  return obj

def get_input_arguments( foo, kwargs ):
  '''helper methods to gently merge defaults and given kwargs'''
  defaults = foo.__kwdefaults__
  if defaults is not None:
    for param_name, param_value in defaults.items():
      if param_name not in kwargs:
        kwargs[param_name] = param_value
  return kwargs

def verify_types(foo):
  '''' verifies types given from API user '''
  def verify_types_impl(*args, **kwargs):
    annotations = dict(foo.__annotations__)
    kwargs = get_input_arguments( foo, kwargs )
    for param_name, param_type in annotations.items():
      if param_name != 'db':
        assert isinstance(kwargs[param_name], param_type), f'`{param_name}` is {str(type(kwargs[param_name]))} type, but should be {str(param_type)} type'
    return foo(db=args[0]['db'], **kwargs)
  return verify_types_impl

def require_unsigned(*params_to_check):
  ''' verifies is given value is non-negative number '''
  def require_positive_wrap(foo):
    def require_positive_impl(**kwargs):
      kwargs = get_input_arguments( foo, kwargs )
      for param_name in params_to_check:
        if param_name != 'db':
          assert isinstance( kwargs[param_name], int )
          assert kwargs[param_name] >= 0
      return foo(**kwargs)
    return require_positive_impl
  return require_positive_wrap


@verify_types
@require_unsigned('block_num')
async def get_ops_in_block(*, db, block_num : int, only_virtual : bool, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  return build_response( await backend().get_ops_in_block( db, block_num, only_virtual, include_reversible) )

@verify_types
@require_unsigned('block_range_begin', 'block_range_end', 'limit')
async def enum_virtual_ops(*, db, block_range_begin : int, block_range_end : int, operation_begin : int = 0, limit : int = DEFAULT_LIMIT, filter : int = None, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, group_by_block : bool = False, **kwargs):
  assert block_range_end > block_range_begin, 'Block range must be upward'
  return build_response( await backend().enum_virtual_ops( db, filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible, group_by_block ) )

@verify_types
async def get_transaction(*, db, id : str, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  return build_response( await backend().get_transaction( db, id, include_reversible ) )

@verify_types
@require_unsigned('limit')
async def get_account_history(*, db, account : str, start : int, limit : int = DEFAULT_LIMIT, operation_filter_low : int = 0, operation_filter_high : int = 0, include_reversible : bool = DEFAULT_INCLUDE_IRREVERSIBLE, **kwargs):
  filter = ( operation_filter_high << 32 ) | operation_filter_low
  start = start if start >= 0 else 9223372036854775807 # max bigint in psql

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