from typing import List, Tuple


class result:
  def __init__( self, result, id : int, jsonrpc : str = "2.0" ):
    self.jsonrpc = jsonrpc
    self.result = result
    self.id = id

class operation:
  def __init__(self, obj : str):
    from json import loads
    data = loads(obj)
    self.type = data["type"]
    self.value = data["value"]

class api_operation:
  def __init__(self, block : int, obj):
    assert obj is not None
    self.trx_id : str = obj["_trx_id"]
    self.block : int = obj['_block'] if block is None else block
    self.trx_in_block : int = obj["_trx_in_block"]
    self.op_in_trx : int = obj["_op_in_trx"]
    self.virtual_op : int = int(obj["_virtual_op"])
    self.timestamp : str = obj["_timestamp"]
    self.op : operation = operation(obj["_value"])
    self.operation_id : int = obj["_operation_id"]

class api_operations_container:
  item = api_operation
  def __init__(self, block, iterable : list):
      assert iterable is not None
      self.ops : list = [ api_operations_container.item( block, row ) for row in iterable ]

class transaction:
  def __init__(self, trx_id, obj):
    assert obj is not None
    self.ref_block_num : int = obj['_ref_block_num']
    self.ref_block_prefix : int = obj['_ref_block_prefix']
    self.expiration : str = obj['_expiration']
    self.operations : list = obj['_value']
    self.extensions : list = []
    self.signatures : list = obj['_signature']
    self.transaction_id : str = trx_id
    self.block_num : str = obj['_block_num']
    self.transaction_num : str = obj['_trx_in_block']

class ops_in_block(api_operations_container): pass
class ops_by_block_wrapper:
  def __init__(self, iterable: list, block : int, timestamp : str, irreversible : bool):
      self.ops = iterable
      self.block = block
      self.timestamp = timestamp
      self.irreversible = irreversible

class virtual_ops(api_operations_container):

  def __init__(self, irreversible_block : int, iterable: list):
    super().__init__(None, iterable)
    self.ops_by_block : list = []
    self.next_block_range_begin : int = 0
    self.next_operation_begin : int = 0
    self.__setup_pagination()

    if irreversible_block is not None:
      self.__group_by_block(irreversible_block)
      self.ops.clear()

  def __setup_pagination(self):
    last_op : api_operation = self.ops[-1]
    self.next_block_range_begin = last_op.block
    self.next_operation_begin = last_op.operation_id
    self.ops.remove(last_op)

  def __group_by_block(self, irreversible_block):
    supp = dict()
    for item in self.ops:
      if item.block in supp:
        supp[item.block].append(item)
      else:
        supp[item.block] = [item]

    self.ops_by_block = []
    for block, items in supp.items():
      self.ops_by_block.append( ops_by_block_wrapper(
        iterable=items, 
        block=block, 
        timestamp=items[0].timestamp,
        irreversible=block > irreversible_block
      ))


class account_history_item:
  def __init__(self, row):
    self.trx_id : str = row["_trx_id"]
    self.block : int = row["_block"]
    self.trx_in_block : int = row["_trx_in_block"]
    self.op_in_trx : int = row["_op_in_trx"]
    self.virtual_op : int = row["_virtual_op"]
    self.timestamp : str = row["_timestamp"]
    self.op : operation = operation( row["_value"] )

class account_history:
  def __init__(self, iterable):
      self.history : List[ Tuple[ int, account_history_item ] ] = [ self.__format_item( row ) for row in iterable ]

  def __format_item( self, row ) -> Tuple[ int, account_history_item ]:
    return (
      row["_operation_id"],
      account_history_item( row )
    )