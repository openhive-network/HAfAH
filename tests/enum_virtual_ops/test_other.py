from . import *

async def enum_with_other_options( api : api_t, limit : int = 1, operation_begin : int = 0) -> virtual_ops:
  return await api.enum_virtual_ops( 
    filter=0,
    block_range_begin=0,
    block_range_end=100,
    operation_begin=operation_begin,
    limit=limit,
    include_reversible=True
  )

async def test_limit(api : api_t):
  vops = await enum_with_other_options(api, limit=10)
  assert len(vops.ops) == 10

async def test_negative_limit(api : api_t):
  with pytest.raises(AssertionError):
    await enum_with_other_options(api, limit=-10)

def log(obj):
  from json import dumps
  print(dumps( obj, default=vars ), flush=True)

async def test_operation_begin(api : api_t):
  vops = await enum_with_other_options(api, operation_begin=5)
  print(len(vops.ops))
  vops = await enum_with_other_options(api, operation_begin=4)
  print(len(vops.ops))
  vops = await enum_with_other_options(api, operation_begin=3)
  print(len(vops.ops))
  vops = await enum_with_other_options(api, operation_begin=2)
  print(len(vops.ops))
  vops = await enum_with_other_options(api, operation_begin=1)
  print(len(vops.ops))
  # log(vops)
