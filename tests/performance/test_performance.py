from . import *
from time import perf_counter
from random import randint
from .datasets import *


async def measure_calls_per_time( api : api_t, functor, time : int = 1) -> int:
  '''returns amount of calls per given time'''
  now = perf_counter()
  calls = 0
  while perf_counter() - now <= time:
    await functor(api)
    calls += 1
  return calls

async def random_enum_virtual_ops(api : api_t):
  await api.get_account_history(
    account=accounts[randint(0, len(accounts) - 1)],
    start=0,
    limit=1000,
    operation_filter_high=0,
    operation_filter_low=0,
    include_reversible=True
  )

async def random_get_account_history(api : api_t):
  await api.enum_virtual_ops( 
    filter=0,
    block_range_begin=randint(0, 100),
    block_range_end=randint(101, 200),
    operation_begin=0,
    limit=1000,
    include_reversible=True
  )

async def random_get_ops_in_block(api : api_t):
  await api.get_ops_in_block(
    block_num=randint(2_000_000, 3_000_000),
    only_virtual=False,
    include_reversible=True
  )


async def random_get_transaction(api : api_t):
  await api.get_transaction(
    trx_hash=hashes[randint(0, len(hashes) - 1)],
    include_reversible=True
  )


async def test_enum_virtual_ops(api : api_t):
  print()
  api.enum_virtual_ops
  count = await measure_calls_per_time(api, random_enum_virtual_ops, 10)
  print(f"test_enum_virtual_ops: {count}")
  assert count > 0

async def test_get_account_history(api : api_t):
  print()
  api.enum_virtual_ops
  count = await measure_calls_per_time(api, random_get_account_history, 10)
  print(f"test_get_account_history: {count}")
  assert count > 0

async def test_get_ops_in_block(api : api_t):
  print()
  api.enum_virtual_ops
  count = await measure_calls_per_time(api, random_get_ops_in_block, 10)
  print(f"test_get_ops_in_block: {count}")
  assert count > 0

async def test_get_transaction(api : api_t):
  print()
  api.enum_virtual_ops
  count = await measure_calls_per_time(api, random_get_transaction, 10)
  print(f"test_get_transaction: {count}")
  assert count > 0
