from typing import Any
from ah.server.db import Db
from json import dumps

def format_array(array, type = 'INT'):
  if array is None:
    return f'ARRAY[]::{type}[]'
  return "ARRAY" + dumps(array) + f"::{type}[]" # if len(array) else f'ARRAY[]::{type}[]'

class account_history_db_connector:
  def __init__(self, args : dict) -> None:
    self._conn : Db = args['db']
    assert self._conn is not None
    self._id : Any = args['id']
    self._schema = 'hafah_python'
    self._app_context_name = 'account_history_python'

  def _get_db(self) -> Db:
    assert self._conn is not None
    return self._conn

  async def _get_all(self, query, **kwargs):
    return await self._get_db().query_all(query + f' -- ## ID: {self._id}', **kwargs)

  async def get_multi_signatures_in_transaction(self, trx_hash : bytes ):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.get_multi_signatures_in_transaction( :trx_hash )",
      trx_hash=trx_hash
    )

  async def get_ops_in_transaction(self, block_num : int, trx_in_block : int ):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.get_ops_in_transaction( :block_num, :trx_in_block )",
      block_num=block_num,
      trx_in_block=trx_in_block
    )

  async def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.get_ops_in_block( :block_num,  :only_virt, :include_reversible )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible
    )

  async def get_transaction(self, trx_hash : bytes, include_reversible : bool ):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.get_transaction( :trx_hash, :include_reversible )",
      trx_hash=trx_hash,
      include_reversible=include_reversible
    )

  async def enum_virtual_ops(self, filter : list, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.enum_virtual_ops( {format_array(filter)}, :block_range_begin, :block_range_end, :operation_begin, :limit, :include_reversible )",
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit,
      include_reversible=include_reversible
    )

  async def get_account_history(self, filter : list, account : str, start : int, limit : int, include_reversible : bool):
    return await self._get_all(
      f"SELECT * FROM {self._schema}.ah_get_account_history( {format_array(filter)}, :account, :start ::BIGINT, :limit, :include_reversible )",
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible
    )

  async def get_irreversible_block_num(self) -> int:
    result = await self._get_all(f"SELECT hive.app_get_irreversible_block( '{self._app_context_name}' ) as num")
    return result[0]['num']

  async def get_operation_id_types(self):
    ''' for tests only '''
    return await self._get_all("SELECT name, id FROM hive.operation_types")

  async def get_virtual_op_offset(self) -> int:
    result = await self._get_all("SELECT MAX(id) as id FROM hive.operation_types WHERE is_virtual=False")
    return result[0]['id']
