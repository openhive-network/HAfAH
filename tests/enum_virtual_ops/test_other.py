from . import *

async def enum_with_other_options( api : api_t, limit : int = 100, operation_begin : int = 0, group_by_block : bool = False) -> virtual_ops:
  return await api.enum_virtual_ops( 
    filter=0,
    block_range_begin=1,
    block_range_end=5,
    operation_begin=operation_begin,
    limit=limit,
    include_reversible=True,
    group_by_block=group_by_block
  )

async def test_limit(api : api_t):
  vops = await enum_with_other_options(api, limit=10)
  assert len(vops.ops) == 10

async def test_negative_limit(api : api_t):
  with pytest.raises(AssertionError):
    await enum_with_other_options(api, limit=-10)

async def test_operation_begin(api : api_t):
  for i in range(112, 1, 2):
    vops = await enum_with_other_options(api, operation_begin=i)
    assert len(vops.ops) == i / 2

async def test_negative_operation_begin(api : api_t):
  await enum_with_other_options( api, operation_begin=-1 )

async def test_group_by_block_fill(api : api_t):
  vops = await enum_with_other_options(api, group_by_block=False)
  assert len(vops.ops) > 0
  assert len(vops.ops_by_block) == 0

  vops = await enum_with_other_options(api, group_by_block=True)
  assert len(vops.ops) == 0
  assert len(vops.ops_by_block) == 4

async def test_pagination(api : api_t):
  op_id = 2
  for i in range(1,112):
    vops = await enum_with_other_options(api, limit=1, operation_begin=op_id)
    for op in vops.ops:
      assert op_id <= op.operation_id 
    op_id = vops.next_operation_begin