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

class api_operations:
  item = api_operation
  def __init__(self, block, iterable : list):
      assert iterable is not None
      self.ops : list = [ api_operations.item( block, row ) for row in iterable ]

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

class ops_in_block(api_operations): pass

class virtual_ops(api_operations):
  def __init__(self, iterable: list):
      super().__init__(None, iterable)

'''
[
        999,
        {
          "trx_id": "97cae29dce3cffa37da96082943e612264716048",
          "block": 41745907,
          "trx_in_block": 11,
          "op_in_trx": 0,
          "virtual_op": 1,
          "timestamp": "2020-03-18T01:12:15",
          "op": {
            "type": "effective_comment_vote_operation",
            "value": {
              "voter": "sammie",
              "author": "hiveio",
              "permlink": "announcing-the-launch-of-hive-blockchain",
              "weight": 108,
              "rshares": "7229031685",
              "total_vote_weight": 21629808,
              "pending_payout": {
                "amount": "150713",
                "precision": 3,
                "nai": "@@000000013"
              }
            }
          },
          "operation_id": 0
        }
      ]

'''

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
      self.history : list = [ self.__format_item( row ) for row in iterable ]

  def __format_item( self, row ) -> list:
    return [
      row["_operation_id"],
      account_history_item( row )
    ]