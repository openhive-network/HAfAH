from typing import Any, List, Union, Callable
from jsonrpcserver.exceptions import ApiError
from enum import IntEnum

class uint(IntEnum):
  uint32_t = 2**32
  uint64_t = 2**64

JSON_RPC_SERVER_ERROR       = -32000
JSON_RPC_ERROR_DURING_CALL  = -32003

def translate_typename(T : type) -> str:
  return {
    type(None): "null_type",
    int: "uint64_type",
    float: "double_type",
    bool: "bool_type",
    str: "string_type",
    list: "array_type",
    dict: "object_type",
    bytes: "blob_type"
  }.get(T, "unknown_type")

class BadCastException(ApiError):
  def __init__(self, expected_type : type, given_type : type):
    expected_type = translate_typename(expected_type)
    given_type = translate_typename(given_type)
    super().__init__(f"Bad Cast:Invalid cast from {given_type} to {expected_type}", JSON_RPC_SERVER_ERROR)

class InvalidArgCount(ApiError):
  def __init__(self, min_args : int, given_args : int):
    super().__init__(f"Assert Exception:args.size()=={min_args}: Expected {min_args} argument(s), was {given_args}", JSON_RPC_ERROR_DURING_CALL)

class CustomParserApiException(ApiError):
  def __init__(self, expected_type : type):
    super().__init__(f"Parse Error:Couldn't parse {translate_typename(expected_type)}", JSON_RPC_SERVER_ERROR)

class CustomBoolParserApiException(ApiError):
  def __init__(self):
    super().__init__('Bad Cast:Cannot convert string to bool (only "true" or "false" can be converted)', JSON_RPC_SERVER_ERROR)

class CustomOutOfRangeException(ApiError):
  def __init__(self, name, max, given):
    super().__init__(f"Assert Exception:args.{name} <= {max}: {name} of {given} is greater than maxmimum allowed", JSON_RPC_ERROR_DURING_CALL)

class NotSet: pass
class TypeValue:
  def __init__(self, itype, value = NotSet()):
    self.type : Union[type, tuple] = itype
    if hasattr(self.type, '__args__') and type(self.type.__args__) in [tuple, list]:
      self.type = self.type.__args__
    self.value = value

class Argument:
  def __init__(self, name : str, expected_type : type, given_value : Any, default_value : Any = NotSet()):
    assert expected_type is not NotSet, f'annotation for {name} is not set'
    self.name = name
    self.expected = TypeValue(expected_type, default_value)
    self.given = TypeValue(type(given_value), given_value)

  def validate(self):
    if self.expected.value is None and self.given.value is None:
      return
    elif not isinstance(self.given.value, self.expected.type):
      raise BadCastException(self.expected.type, self.given.type)

  def update(self, new):
    print(f'updating: {self.name}, with new (type={type(new).__name__}): {new}', flush=True)
    if isinstance(new, TypeValue):
      self.given = new
    elif isinstance(new, Argument):
      print(f'old: `{self.given.value}` (type={self.given.type}) | new: `{new.given.value}` (type={new.given.type})', flush=True)
      self.given = new.given
    elif isinstance(new, type):
      self.given = TypeValue(new)
    else:
      self.given = TypeValue(type(new), new)

def get_traceback(e):
    import traceback
    lines = traceback.format_exception(type(e), e, e.__traceback__)
    return ''.join(lines)

def get_input_arguments_as_kwargs( foo, args : list, kwargs : dict ):
  '''helper method to extract arguments as kwargs'''
  annotes : dict = foo.__annotations__
  defaults = foo.__kwdefaults__ if foo.__kwdefaults__ is not None else {}
  if kwargs is not None and len(kwargs) > 0:
    assert args is None or len(args) == 0
    return defaults, { key : value for key, value in kwargs.items() if key in annotes }
  elif args is not None and len(args) > 0:
    assert kwargs is None or len(kwargs) == 0
    avalues = list(annotes.items())
    return defaults, { avalues[i][0] : item for i, item in enumerate(args[:len(annotes)]) }
  else:
    assert len(annotes) - len(defaults) == 0, "not enough params"
    return defaults, defaults

def get_input_arguments( foo, args : list, kwargs : dict ) -> List[Argument]:
  annotes : dict = foo.__annotations__
  defaults, params = get_input_arguments_as_kwargs(foo, args, kwargs)
  stats = {"min_args": len(annotes) - len(defaults), "given_args": len(params)}
  updated_defaults = defaults.copy()
  updated_defaults.update(params)
  arguments = []
  for key, value in updated_defaults.items():
    arguments.append(Argument(
      name          = key,
      expected_type = annotes.get(key, NotSet),
      given_value   = value,
      default_value = defaults.get(key, NotSet())
    ))
  return arguments, stats

def process_types(*gloabal_actions, **additional_actions):
  '''
  Verifies is incoming arguments fits to annotations. If argument does not have annotations will be ignored

  @param gloabal_actions    - additional checks/actions that will be executed in given order on
                              every parameter (before additional_actions)
  @param additional_actions - additional checks/actions done before final check
                              in format: param_name=action or param_name=[action_0, action_1]
  '''

  def process_global_actions(arg : Argument) -> Argument:
    for foo in gloabal_actions:
      arg.update(foo(arg))
    return arg

  def process_aditional_actions(arg : Argument) -> Argument:
    actions = additional_actions.get(arg.name, None)

    if actions is None:
      print('exiting additional actions', flush=True)
      return arg
    elif isinstance(actions, tuple):
      actions = list(actions)
    elif not isinstance(actions, list):
      actions = [actions]

    for foo in actions:
      arg.update(foo(arg))
    return arg

  def verify_types_wrap(foo):
    ''' verifies types given from user to API '''
    def verify_types_impl(api_type, ctx, *args, **kwargs):
      arguments, arg_stats = get_input_arguments( foo, args, kwargs )
      try:
        for arg in arguments:
          arg : Argument = arg
          if arg.given.value is NotSet and arg.expected.value is NotSet:
            raise InvalidArgCount(**arg_stats)
          arg.update(process_global_actions(arg))
          arg.update(process_aditional_actions(arg))
          arg.validate()
      except Exception as e:
        print(f'got exception: {e}', flush=True)
        print(f'with traceback: {get_traceback(e)}', flush=True)
        print(f'kwargs={kwargs}', flush=True)
        raise e

      return foo(ctx, api_type, **{arg.name: arg.given.value for arg in arguments})
    return verify_types_impl
  return verify_types_wrap

def require_type(req_type = (int, float)):
  def require_type_impl(arg : Argument):
    if not isinstance(arg.given.value, req_type):
      raise CustomParserApiException(req_type if type(req_type) is type else req_type[0])
    return arg
  return require_type_impl

def str2bool(arg : Argument):
  print(f'converting string to obol ', flush=True)
  if arg.given.type is bool:
    return arg
  elif arg.given.type is str:
    if 'true' == arg.given.value:
      return True
    elif 'false' == arg.given.value:
      return False

  raise CustomBoolParserApiException()

def convert(output_type : type = int):
  def convert_impl(arg : Argument) -> int:
    if arg.given.type is not output_type:
      try:
        arg.update( output_type(arg.given.value) )
      finally:
        require_type(output_type)(arg)
    return arg
  return convert_impl

def unsigned(utype : uint = uint.uint32_t):
  def unsigned_impl(arg : Argument):
    arg = convert(int)(arg)
    if arg.given.value < 0:
      arg.given.value += int(utype)
    return arg
  return unsigned_impl

def max_value(maximum : int):
  def max_value_impl(arg : Argument):
    arg = convert(int)(arg)
    if arg.given.value > maximum:
      raise CustomOutOfRangeException(arg.name, maximum, arg.given.value)
    return arg
  return max_value_impl


def convert_maybe(arg : Argument):
  if arg.given.type is str:
    if arg.expected.type in (int, float):
      arg.update(convert(arg.expected.type)(arg))
    elif arg.expected.type is bool:
      arg.update(str2bool(arg))

  return arg
