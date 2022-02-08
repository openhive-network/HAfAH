from typing import Dict, Tuple
import ah.api.async.endpoints as api_t
from ah.db.objects import virtual_ops
import asyncio
import pytest
from pytest import fixture


try:
  pytestmark = pytest.mark.asyncio
except Exception as e:
  print(
    """
verify that you have `pytest-asyncio` packet
command to install: `pip3 install pytest-asyncio --user`
    """
  )

@fixture(scope='session')
async def op_name_id_translation(api : api_t) -> Dict[ str, int ]:
  return { row['name']: row['id'] for row in await api.backend().api.get_operation_id_types() }
  # return {
  #   'account_witness_vote_operation': 12,
  #   'producer_reward_operation': 62
  # }

def operation_ids_to_binary( op_ids : list ) -> int:
  '''converts given operation id list to binary filter'''
  op_ids = sorted(op_ids)
  result = 0
  for op_id in op_ids:
    result += pow(2, op_id)
  return result

def split_binary_filter( input : int ) -> Tuple[int, int]:
  low = input & 0xFF_FF_FF_FF
  high = input >> 32
  return (high, low)
