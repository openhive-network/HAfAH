from . import *

@fixture
def op_name_id_translation():
  return {
    'account_witness_vote_operation': 12,
    'producer_reward_operation': 62
  }

def operation_ids_to_binary( op_ids : list ) -> int:
  op_ids = sorted(op_ids)
  result = 0
  for op_id in op_ids:
    result += pow(2, op_id)
  return result

async def enum_with_filters( api : api_t, op_ids : list) -> virtual_ops:
  return await api.enum_virtual_ops( 
    filter=operation_ids_to_binary(op_ids),
    block_range_begin=0,
    block_range_end=10,
    operation_begin=0,
    limit=1000,
    include_reversible=True
  )

async def test_empty_filter(api : api_t):
  vops = await enum_with_filters( api, [] )
  op_types = set()
  for vop in vops.ops:
    op_types.add(vop.op.type)
  assert len(op_types) > 1

async def test_single_operation_type_in_filter(api : api_t, op_name_id_translation : dict):
  filtered_id = 62
  vops = await enum_with_filters( api, [filtered_id] )
  for vop in vops.ops:
    assert op_name_id_translation[vop.op.type] == filtered_id

async def test_multiple_operation_types_in_filter(api : api_t, op_name_id_translation : dict):
  filtered_ids = [62, 12]
  vops = await enum_with_filters( api, filtered_ids )
  for vop in vops.ops:
    assert op_name_id_translation[vop.op.type] in filtered_ids

