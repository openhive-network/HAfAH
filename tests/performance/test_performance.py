from . import *
from time import perf_counter
from random import randint
from .datasets import *
from requests import post
import json

MEASURE_TIME = 10 # seconds
BLOCK_UPPER =  4_500_000 - min(len(accounts), len(hashes))


def do_request(url : str, endpoint : str, **kwargs):
  post(
    url=url,
    json={
      "jsonrpc": "2.0",
      "method": f"account_history_api.{endpoint}", 
      "params": kwargs,
      "id": 1
      }
    )

def measure_calls_per_time( functor, url : str = 1) -> int:
  '''returns amount of calls per given time'''
  medium = None
  counter = 1
  for _ in range(5):
    now = perf_counter()
    calls = 0
    while perf_counter() - now <= MEASURE_TIME:
      functor(url, counter)
      calls += 1
      counter += 1
    if medium is None:
      medium = calls
    else:
      medium += calls
      medium /= 2
  return medium / MEASURE_TIME

def random_get_account_history(url : str, i):
  do_request(url, "get_account_history",
    account=accounts[i % len(accounts)],
    start=0,
    limit=1000,
    operation_filter_high=0,
    operation_filter_low=0,
    include_reversible=True
  )

def random_enum_virtual_ops(url : str, i):
  do_request(url, "enum_virtual_ops",
    block_range_begin=BLOCK_UPPER+i,
    block_range_end=BLOCK_UPPER+i+5,
    operation_begin=0,
    limit=1000,
    include_reversible=True
  )

def random_get_ops_in_block(url : str, i):
  do_request(url, "get_ops_in_block",
    block_num=BLOCK_UPPER+i,
    only_virtual=False,
    include_reversible=True
  )

def random_get_transaction(url : str, i):
  do_request(url, "get_transaction",
    trx_hash=hashes[i % len(hashes)],
    include_reversible=True
  )

async def test_enum_virtual_ops(server : str):
  print()
  count = measure_calls_per_time(random_enum_virtual_ops, server)
  print(f"test_enum_virtual_ops: {count}")
  assert count > 0

async def test_get_account_history(server : str):
  print()
  count = measure_calls_per_time(random_get_account_history, server)
  print(f"test_get_account_history: {count}")
  assert count > 0

async def test_get_ops_in_block(server : str):
  print()
  count = measure_calls_per_time(random_get_ops_in_block, server)
  print(f"test_get_ops_in_block: {count}")
  assert count > 0

async def test_get_transaction(server : str):
  print()
  count = measure_calls_per_time(random_get_transaction, server)
  print(f"test_get_transaction: {count}")
  assert count > 0
