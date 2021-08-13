from . import *

async def account_history_ranges(api : api_t, start : int = 0, limit : int = 1_000) -> account_history:
  return await api.get_account_history(
    account='axa-5',
    start=start,
    limit=limit,
    operation_filter_high=0,
    operation_filter_low=0,
    include_reversible=True
  )

async def test_start_range(api : api_t):
  result = await account_history_ranges( api, start=999 )
  assert len(result.history) == 3

async def test_start_narrowed_range(api : api_t):
  for i in range(1, 3):
    result = await account_history_ranges( api, start=i )
    assert len(result.history) == i

async def test_operation_id_validate_range(api : api_t):
  for i in range(3):
    result = await account_history_ranges( api, start=i )
    for record in result.history:
      assert record[0] <= i

async def test_reversed_order( api : api_t ):
  MAX_OP_ID = 3

  vops_pos = await account_history_ranges( api, start=MAX_OP_ID )
  vops_neg = await account_history_ranges( api, start=-MAX_OP_ID )

  for i in range(MAX_OP_ID):
    assert vops_pos.history[i][0] == vops_neg.history[MAX_OP_ID - 1 - i][0]

