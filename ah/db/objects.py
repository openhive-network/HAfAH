from functools import partial
from pyclbr import Function
from typing import List, Tuple
from json import loads


class result:
  def __init__( self, result, id : int, jsonrpc : str = "2.0" ):
    self.jsonrpc = jsonrpc
    self.result = result
    self.id = id

class api_operations_container:
  def __init__(self, iterable : list, *, create_item : Function ):
      assert iterable is not None, "iterable can not be none"
      self.ops : list = [ create_item( row=row ) for row in iterable ]

class transaction:
  def __init__(self, trx_id, obj):
    assert obj is not None
    self.ref_block_num : int = obj['_ref_block_num']
    self.ref_block_prefix : int = obj['_ref_block_prefix']
    self.expiration : str = obj['_expiration']
    self.operations : list = obj['_value']
    self.extensions : list = []
    self.signatures : list = [x for x in obj['_signature'] if x is not None]
    self.transaction_id : str = trx_id
    self.block_num : str = obj['_block_num']
    self.transaction_num : str = obj['_trx_in_block']

class condenser_api_objects: # namespace

  def operation(obj):
    obj = loads(obj)
    return [
      obj['type'],
      obj['value']
    ]
  class api_operation:
    def __init__(self, row : dict, block : int):
      assert row is not None, "row should not be None"

      self.trx_id : str = row["_trx_id"]
      self.block : int = row["_block"] if block is None else block
      self.trx_in_block : int = row["_trx_in_block"]
      self.op_in_trx : int = row["_op_in_trx"]
      self.virtual_op : bool = row["_virtual_op"]
      self.timestamp : str = row["_timestamp"]
      self.op = condenser_api_objects.operation( row["_value"] )

  class account_history_item(api_operation):
    def __init__(self, row):
      super().__init__(row=row, block=None)

class account_history_api_objects: # namespace

  class operation:
    def __init__(self, obj):
      if not isinstance(obj, list):
        obj = condenser_api_objects.operation(obj)
      assert len(obj) == 2, 'given array is not in proper format'
      self.type = obj[0]
      self.value = obj[1]

  class api_operation(condenser_api_objects.api_operation):

    vop_flag = 0x8000000000000000

    def __init__(self, row, *, block : int, include_op_id = False):
      super().__init__(row=row, block=block)
      self.op = account_history_api_objects.operation(self.op)
      self.operation_id = account_history_api_objects.api_operation.set_operation(row["_operation_id"], include_op_id)

    @staticmethod
    def set_operation(op, include_op_id):
      _res = str(account_history_api_objects.api_operation.vop_flag | int(op)) if include_op_id else 0
      return _res

    @staticmethod
    def get_operation(op):
      return (~account_history_api_objects.api_operation.vop_flag) & int(op)

  class ops_by_block_wrapper:
    def __init__(self, iterable: list, block : int, timestamp : str, irreversible : bool):
        self.block = block
        self.irreversible = irreversible
        self.timestamp = timestamp
        self.ops = iterable

  class virtual_ops(api_operations_container):

    def __init__(self, irreversible_block : int, iterable: list):
      super().__init__(iterable, create_item=partial(account_history_api_objects.api_operation, block=None, include_op_id=True))
      self.ops_by_block : list = []
      self.next_block_range_begin : int = 0
      self.next_operation_begin : int = 0

      if irreversible_block is not None:
        self.__group_by_block(irreversible_block)
        self.ops.clear()

    def get_pagination_data(self, block_range_end, limit):
      _len = max( len(self.ops), len(self.ops_by_block) )

      if _len and _len == limit:
        last_op : account_history_api_objects.api_operation = None

        if len(self.ops):
          last_op = self.ops[-1]
        else:
          last_op_wrapper = self.ops_by_block[-1]
          last_op = last_op_wrapper.ops[-1]

        _op_id = account_history_api_objects.api_operation.get_operation(last_op.operation_id)
        return True, last_op.block, _op_id
      else:
        self.next_block_range_begin = block_range_end
        return False, 0, 0

    def update_pagination_data(self, next_block_range_begin, next_operation_begin):
      self.next_block_range_begin = next_block_range_begin
      self.next_operation_begin   = account_history_api_objects.api_operation.set_operation(next_operation_begin, True)

    def __group_by_block(self, irreversible_block):
      supp = dict()
      for item in self.ops:
        if item.block in supp:
          supp[item.block].append(item)
        else:
          supp[item.block] = [item]

      self.ops_by_block = []
      for block, items in supp.items():
        self.ops_by_block.append( account_history_api_objects.ops_by_block_wrapper(
          iterable=items,
          block=block,
          timestamp=items[0].timestamp,
          irreversible=block <= irreversible_block
        ))

  class account_history_item(condenser_api_objects.account_history_item):
    def __init__(self, row):
      super().__init__(row)
      self.op = account_history_api_objects.operation(self.op)
      self.operation_id : int = 0


class account_history:
  def __init__(self, iterable, *, item_type ):
      self.history = [ self.__format_item( row, item_type ) for row in iterable ]

  def __format_item( self, row, item_type ):
    return (
      row["_operation_id"],
      item_type( row )
    )

class account_history_api: # namespace
  operation = account_history_api_objects.operation

  @staticmethod
  def get_account_history(iterable):
    return account_history(iterable, item_type=account_history_api_objects.account_history_item)

  @staticmethod
  def get_transaction(trx_id, obj):
    return transaction(trx_id, obj)

  @staticmethod
  def get_ops_in_block(block, iterable : list, *, include_op_id = False):
    return api_operations_container(iterable, create_item=partial(account_history_api_objects.api_operation, block=block, include_op_id=include_op_id))

  @staticmethod
  def enum_virtual_ops(irreversible_block : int, iterable: list):
    return account_history_api_objects.virtual_ops(irreversible_block, iterable)

  @staticmethod
  def is_old_schema():
    return True

class condenser_api: # namespace
  operation = condenser_api_objects.operation

  @staticmethod
  def get_account_history(iterable):
    return account_history(iterable, item_type=condenser_api_objects.account_history_item).history

  @staticmethod
  def get_transaction(trx_id, obj):
    return transaction(trx_id, obj)

  @staticmethod
  def get_ops_in_block(block, iterable: list):
    return api_operations_container(iterable, create_item=partial(condenser_api_objects.api_operation, block=block)).ops

  @staticmethod
  def enum_virtual_ops(irreversible_block : int, iterable: list):
    assert False, "not supported"

  @staticmethod
  def is_old_schema():
    return False
