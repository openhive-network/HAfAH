from functools import partial
from json import loads
from typing import Callable


class result:
  def __init__( self, result, id : int, jsonrpc : str = "2.0" ):
    self.jsonrpc = jsonrpc
    self.result = result
    self.id = id

class api_operations_container:
  def __init__(self, iterable : list, *, create_item : Callable ):
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
    return loads(obj)

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

  operation = condenser_api_objects.operation

  class api_operation(condenser_api_objects.api_operation):

    def __init__(self, row, *, block : int, fill_operation_id : bool = False):
      super().__init__(row=row, block=block)
      self.operation_id = account_history_api_objects.api_operation.set_operation_id(row["_operation_id"]) if fill_operation_id else 0

    @staticmethod
    def set_operation_id(op_id):
      assert op_id is not None, "op_id cannot be None"
      return str(op_id) if op_id >= 0xffffffff else op_id

    @staticmethod
    def get_opertaion_id(op_id):
      return int(op_id) if isinstance(op_id, str) else op_id

  class ops_by_block_wrapper:
    def __init__(self, iterable: list, block : int, timestamp : str, irreversible : bool):
        self.block = block
        self.irreversible = irreversible
        self.timestamp = timestamp
        self.ops = iterable

  class virtual_ops(api_operations_container):

    def __init__(self, irreversible_block : int, iterable: list, block_range_end : int, limit : int, get_pagination_data_call : Callable):
      super().__init__(iterable, create_item=partial(account_history_api_objects.api_operation, block=None, fill_operation_id=True ))
      self.ops_by_block : list = []
      self.next_block_range_begin : int = 0
      self.next_operation_begin : int = 0

      ops_total_count = len(self.ops) # thanks to this var, there is no need to loop and count in `__prepare_pagination_params`, when representation mode is set group_by_block
      if irreversible_block is not None:
        self.__group_by_block(irreversible_block)
        self.ops.clear()

      self.__prepare_pagination_params(block_range_end, limit, get_pagination_data_call, ops_total_count)

    def __prepare_pagination_params(self, block_range_end, limit, get_pagination_data_call, ops_total_count):
      last_op : account_history_api_objects.api_operation = None
      _block_range_end = block_range_end

      if len(self.ops):
        last_op = self.ops[-1]
        if ops_total_count == limit:
          _block_range_end = last_op.block
      elif len(self.ops_by_block):
          last_op_wrapper : account_history_api_objects.ops_by_block_wrapper = self.ops_by_block[-1]
          last_op = last_op_wrapper.ops[-1]
          total_length = ops_total_count
          if total_length == limit:
            _block_range_end = last_op_wrapper.block

      if last_op is None:
        _op_id = 0
      else:
        _op_id = account_history_api_objects.api_operation.get_opertaion_id(last_op.operation_id)

      _block_range_end, _op_id = get_pagination_data_call(_block_range_end, _op_id, block_range_end)

      self.next_block_range_begin = _block_range_end
      self.next_operation_begin   = account_history_api_objects.api_operation.set_operation_id(_op_id)

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
  def get_ops_in_block(block, iterable : list):
    return api_operations_container(iterable, create_item=partial(account_history_api_objects.api_operation, block=block))

  @staticmethod
  def enum_virtual_ops(irreversible_block : int, iterable: list, block_range_end : int, limit : int, get_pagination_data_call : Callable):
    return account_history_api_objects.virtual_ops(irreversible_block, iterable, block_range_end, limit, get_pagination_data_call)

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
  def enum_virtual_ops(irreversible_block : int, iterable: list, block_range_end : int, limit : int, get_pagination_data_call : Callable):
    assert False, "not supported"

  @staticmethod
  def is_old_schema():
    return False
