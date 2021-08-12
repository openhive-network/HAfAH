from . import *

async def enum_block_range( api : api_t, begin : int, end : int) -> virtual_ops:
  return await api.enum_virtual_ops( 
    filter=0,
    block_range_begin=begin,
    block_range_end=end,
    operation_begin=0,
    limit=1000,
    include_reversible=True
  )

async def test_block_count(api : api_t):
  begin, end = 20, 30
  vops = await enum_block_range( api, begin, end )
  block_nums = set()
  for vop in vops.ops:
    block_nums.add(vop.block)

  assert len(block_nums) == end - begin

async def test_invalid_block_range(api : api_t):
  begin, end = 30, 20
  with pytest.raises(AssertionError):
    await enum_block_range( api, begin, end )

async def test_negative_block_range_begin(api : api_t):
  begin, end = -1, 20
  with pytest.raises(AssertionError):
    await enum_block_range(api, begin, end)

async def test_negative_block_range_end(api : api_t):
  begin, end = -20, -10
  with pytest.raises(AssertionError):
    await enum_block_range(api, begin, end)

async def test_invalid_data_type(api : api_t):
  begin, end = 'lorem', 6.38
  with pytest.raises(AssertionError):
    await enum_block_range(api, begin, end)


'''

should_be_normal  ( NULL::INT[], 9980, 9983, 0, 10000, true );
should_be_normal  ( NULL::INT[], 9980, 9983, 0, 10000, false );
should_be_normal  ( NULL::INT[], 9987, 9990, 0, 10000, true );
should_be_normal  ( NULL::INT[], 9987, 9990, 0, 10000, false );
should_be_normal  ( NULL::INT[], 9989, 9992, 0, 10000, true );
should_be_lesser_than_normal  ( NULL::INT[], 9989, 9992, 0, 10000, false );
should_be_normal  ( NULL::INT[], 9990, 9993, 0, 10000, true );
shoud_be_0  ( NULL::INT[], 9990, 9993, 0, 10000, false );
should_be_normal  ( NULL::INT[], 9991, 9994, 0, 10000, true );
shoud_be_0  ( NULL::INT[], 9991, 9994, 0, 10000, false );

'''
