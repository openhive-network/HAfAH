from typing import List, Tuple
from json import loads


def result(result, id : int, jsonrpc : str = "2.0"):
  return {
    "jsonrpc": jsonrpc,
    "result": result,
    "id": id
  }

def operation(obj : str):
  data = loads(obj)
  return {
    "type": data["type"],
    "value": data["value"]
  }

def api_operation(block : int, obj, *, include_op_id = False):
  assert obj is not None
  return {
    "trx_id" : obj["_trx_id"],
    "block" : obj['_block'] if block is None else block,
    "trx_in_block" : obj["_trx_in_block"],
    "op_in_trx" : obj["_op_in_trx"],
    "virtual_op" : int(obj["_virtual_op"]),
    "timestamp" : obj["_timestamp"],
    "op" : operation(obj["_value"]),
    "operation_id" : str(0x8000000000000000 | int(obj["_operation_id"])) if include_op_id else 0
  }

def api_operations_container(block, iterable : list, *, include_op_id = False):
    assert iterable is not None
    return {
      "ops": [ api_operation( block, row, include_op_id=include_op_id ) for row in iterable ]
    }

def transaction(trx_id, obj):
  assert obj is not None
  return {
    "ref_block_num": obj['_ref_block_num'],
    "ref_block_prefix": obj['_ref_block_prefix'],
    "expiration": obj['_expiration'],
    "operations": obj['_value'],
    "extensions": [],
    "signatures": [x for x in obj['_signature'] if x is not None],
    "transaction_id": trx_id,
    "block_num": obj['_block_num'],
    "transaction_num": obj['_trx_in_block']
  }

ops_in_block = api_operations_container

def ops_by_block_wrapper(iterable: list, block : int, timestamp : str, irreversible : bool):
  return {
    "ops": iterable,
    "block": block,
    "timestamp": timestamp,
    "irreversible": irreversible
  }

def virtual_ops(irreversible_block : int, iterable: list, last_block : int):
  result = api_operations_container(None, iterable, include_op_id=True)
  ops = result["ops"]

  def group_by_block(irreversible_block):
    supp = dict()
    ops_by_block = []

    for item in ops:
      block_num = item['block']
      if block_num in supp:
        supp[block_num].append(item)
      else:
        supp[block_num] = [item]

    for block, items in supp.items():
      ops_by_block.append( ops_by_block_wrapper(
        iterable=items,
        block=block,
        timestamp=items[0]['timestamp'],
        irreversible=block > irreversible_block
      ))
    return ops_by_block

  ops_length = len(ops)
  last_op = ops[-1] if ops_length else {"block": 0, "operation_id": "0"}

  result["next_block_range_begin"] = last_op["block"]
  result["next_operation_begin"] = int(last_op["operation_id"]) if last_block < last_op["block"] else 0
  if ops_length:
    result["ops"].remove(last_op)

  if irreversible_block is not None:
    result["ops_by_block"] = group_by_block(irreversible_block)
    result["ops"].clear()
  else:
    result["ops_by_block"] = []


def account_history_item(row):
  return {
    "trx_id": row["_trx_id"],
    "block": row["_block"],
    "trx_in_block": row["_trx_in_block"],
    "op_in_trx": row["_op_in_trx"],
    "virtual_op": int(row["_virtual_op"]),
    "timestamp": row["_timestamp"],
    "op": operation( row["_value"] ),
    "operation_id": 0
  }

def account_history(iterable):
  return {"history" : [ ( row["_operation_id"], account_history_item( row ) ) for row in iterable ]}

