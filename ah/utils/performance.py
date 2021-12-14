from types import FunctionType
from time import perf_counter
from typing import Union

def log_time(record_name : str, time : float):
    print(f'{record_name} executed in {time * 1_000 :.2f}ms', flush=True)

def build_record_name(foo, extract_identifier : FunctionType, record_name : Union[str, FunctionType], *args, **kwargs):
  if record_name is None:
    record_name = foo.__name__
  elif not isinstance(record_name, str):
    record_name = record_name(args, kwargs)
  return f'[{extract_identifier(args, kwargs)}] {record_name}'

class Timer:
  def __enter__(self) -> "Timer":
    self.__start = perf_counter()
    return self

  def __exit__(self, exception_type : type, exception_value : Exception, exception_traceback):
    self.time = perf_counter() - self.__start
    if exception_type is not None:
      print(f'got {exception_type.__name__} exception: `{exception_value}`, with traceback:' + '\n\n' + str(exception_traceback))
      raise exception_type(exception_value)

def perf(*, extract_identifier : FunctionType, record_name : Union[str, FunctionType] = None):
  def perf_impl(foo : FunctionType):
    def perf_impl_impl(*args, **kwargs):
      with Timer() as tm:
        result = foo(*args, **kwargs)
      log_time(build_record_name(foo, extract_identifier, record_name, *args, **kwargs), tm.time)
      return result
    return perf_impl_impl
  return perf_impl

def async_perf(*, extract_identifier : FunctionType, record_name : Union[str, FunctionType] = None):
  def perf_impl(foo : FunctionType):
    async def perf_impl_impl(*args, **kwargs):
      with Timer() as tm:
        result = await foo(*args, **kwargs)
      log_time(build_record_name(foo, extract_identifier, record_name, *args, **kwargs), tm.time)
      return result
    return perf_impl_impl
  return perf_impl
