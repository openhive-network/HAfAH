from . import *

async def account_history_filter(api : api_t, filter : list) -> account_history:
  high, low = split_binary_filter( operation_ids_to_binary( filter ) )
  return await api.get_account_history(
    account='axa-5',
    start=1000,
    limit=1000,
    operation_filter_high=high,
    operation_filter_low=low,
    include_reversible=True
  )


async def test_empty_filter(api : api_t):
  result = await account_history_filter( api, [] )
  operation_types = set()
  for _, op in result.history:
    operation_types.add(op.op.type)

  assert len(operation_types) > 1

async def test_single_filter(api : api_t, op_name_id_translation : dict):
  filtered_ids = [62]
  result = await account_history_filter( api, filtered_ids )
  for _, op in result.history:
    assert op_name_id_translation[op.op.type] in filtered_ids

async def test_multiple_operation_types_in_filter(api : api_t, op_name_id_translation : dict):
  filtered_ids = [62, 12]
  result = await account_history_filter( api, filtered_ids )
  for _, op in result.history:
    assert op_name_id_translation[op.op.type] in filtered_ids