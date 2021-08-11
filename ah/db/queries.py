from .connection import Db

class account_history_db_connector:
  def __init__(self, db : Db) -> None:
    assert db is not None
    self._conn : Db = db

  def _get_db(self) -> Db:
    assert self._conn is not None
    return self._conn

  def _get_all(self, query, *args, **kwargs):
    return self._get_db().exec( query=query, *args, **kwargs ).fetchall()

  async def get_multi_signatures_in_transaction(self, trx_hash : bytes ):
    return self._get_all(
      "SELECT * FROM get_multi_signatures_in_transaction( :trx_hash )",
      trx_hash=trx_hash
    )

  async def get_ops_in_transaction(self, block_num : int, trx_in_block : int ):
    return self._get_all(
      "SELECT * FROM get_ops_in_transaction( :block_num, :trx_in_block )",
      block_num=block_num,
      trx_in_block=trx_in_block
    )

  async def get_ops_in_block( self, block_num : int, only_virtual : bool ):
    return self._get_all(
      "SELECT * FROM get_ops_in_block( :block_num,  :only_virt )",
      block_num=block_num,
      only_virt=only_virtual
    )

  async def get_transaction(self, trx_hash : bytes ):
    return self._get_all(
      "SELECT * FROM get_transaction( :trx_hash )",
      trx_hash=trx_hash
    )

  async def enum_virtual_ops(self, filter : list, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int ):
    return self._get_all(
      "SELECT * FROM enum_virtual_ops( :filter ::INT[] , :block_range_begin, :block_range_end, :operation_begin, :limit )",
      filter=filter,
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit
    )

  async def get_account_history(self, filter : list, account : str, start : int, limit : int):
    return self._get_all(
      "SELECT * FROM ah_get_account_history( :filter, :account, :start, :limit )",
      filter=filter,
      account=account,
      start=start,
      limit=limit
    )

#   def get_operation_ids(self, values : list):
#     def sql_tuple( item ):
#         return f"({item[0]}, '{item[1]}')"
#     assert len(values)
#     return self._get_all( f"""

# SELECT inputs._id as input_id, hot.id as output_id FROM hive.operation_types as hot
# INNER JOIN ( VALUES 
# { ','.join([ sql_tuple(value) for value in values ]) } 
# ) as inputs(_id, _name) ON hot.name = inputs._name

# """ )


