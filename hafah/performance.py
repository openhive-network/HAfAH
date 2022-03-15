# -*- coding: utf-8 -*-
from types import FunctionType
from time import perf_counter
from typing import Union

class Timer:
  def __enter__(self) -> "Timer":
    self.__start = perf_counter()
    return self

  def __exit__(self, *_, **__):
    self.time = (perf_counter() - self.__start) * 1_000.0

def default_handler(name, time, *_, **__):
    print(f'`{name}` done in {time :.2f}ms', flush=True)

def perf(*, record_name : Union[str, FunctionType] = None, handler : FunctionType = default_handler):
  def perf_impl(foo : FunctionType):
    def perf_impl_impl(*args, **kwargs):
      with Timer() as tm:
        result = foo(*args, **kwargs)
      handler(record_name, tm.time, *args, **kwargs)
      return result
    return perf_impl_impl
  return perf_impl

def async_perf(*, record_name : Union[str, FunctionType] = None, handler : FunctionType = default_handler):
  def perf_impl(foo : FunctionType):
    async def perf_impl_impl(*args, **kwargs):
      with Timer() as tm:
        result = await foo(*args, **kwargs)
      handler(record_name, tm.time, *args, **kwargs)
      return result
    return perf_impl_impl
  return perf_impl
