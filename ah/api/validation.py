from distutils import util

def get_input_arguments( foo, kwargs ):
  '''helper methods to gently merge defaults and given kwargs'''
  defaults = foo.__kwdefaults__
  if defaults is not None:
    for param_name, param_value in defaults.items():
      if param_name not in kwargs:
        kwargs[param_name] = param_value
  return kwargs



def verify_types(*gloabal_actions, **additional_actions):
  '''
  Verifies is incoming arguments fits to annotations

  @param gloabal_actions    - additional checks/actions that will be executed on
                              every parameter (before additional_actions)
  @param additional_actions - additional checks/actions done before final check
                              in format: param_name=action or param_name=[action_0, action_1]
  '''

  def process_global_actions(argument, valid_type : type, param_name : str):
    for foo in gloabal_actions:
      argument = foo(argument, valid_type, param_name)
    return argument

  def process_aditional_actions(argument, actions, valid_type : type, param_name : str):
    if actions is None:
      return argument
    elif not isinstance(actions, list):
      actions = [actions]
    for foo in actions:
      argument = foo(argument, valid_type, param_name)
    return argument

  def verify_types_wrap(foo):
    '''' verifies types given from API user '''
    def verify_types_impl(*args, **kwargs):
      annotations = dict(foo.__annotations__)
      kwargs = get_input_arguments( foo, kwargs )
      for param_name, param_type in annotations.items():
        incoming_param_value = process_global_actions(kwargs[param_name], param_type, param_name)
        incoming_param_value = process_aditional_actions(incoming_param_value, additional_actions.get(param_name, None), param_type, param_name)
        assert isinstance(incoming_param_value, param_type), f'`{param_name}` is `{type(incoming_param_value).__name__}` type, but should be `{param_type.__name__}` type'
        kwargs[param_name] = incoming_param_value

      return foo(args=args[0], **kwargs)
    return verify_types_impl
  return verify_types_wrap

def convert_maybe(incoming_value, param_type : type, param_name : str):
  '''tries to convert to proper type'''
  if isinstance(incoming_value, str) and issubclass(param_type, int) and incoming_value.isnumeric():
    return int(incoming_value)
  elif isinstance(incoming_value, str) and issubclass(param_type, bool):
    return bool(util.strtobool(incoming_value))
  elif isinstance(incoming_value, int) and issubclass(param_type, bool):
    return bool(incoming_value)

  print(f'returning default {param_name}')
  return incoming_value

def is_numeric(value) -> bool:
  return isinstance(value, (int, float))

def require_unsigned(incoming_value, _ : type, param_name : str):
  ''' verifies is given value is non-negative number '''
  if is_numeric(incoming_value):
    assert incoming_value >= 0, f'{param_name} should be greater or equal 0'
  return incoming_value

def max_value(maximum : int):
  def max_value_impl(incoming_value, _ : type, param_name : str):
    if is_numeric(incoming_value):
      assert incoming_value <= maximum, f'{param_name} should be not greater then {maximum}'
    return incoming_value
  return max_value_impl
