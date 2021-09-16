from typing import Any
from ah.server.db import Db
from time import perf_counter

class account_history_db_connector:
  def __init__(self, args : dict) -> None:
    self._conn : Db = args['db']
    assert self._conn is not None
    self._id : Any = args['id']

  def _get_db(self) -> Db:
    assert self._conn is not None
    return self._conn

  async def _get_all(self, query, **kwargs):
    return await self._get_db().query_all(query + f' -- ## ID: {self._id}', **kwargs)

  async def get_multi_signatures_in_transaction(self, trx_hash : bytes ):
    return self._get_all(
      "SELECT * FROM get_multi_signatures_in_transaction( :trx_hash )",
      trx_hash=trx_hash
    )

  async def get_ops_in_transaction(self, block_num : int, trx_in_block : int ):
    return await self._get_all(
      "SELECT * FROM get_ops_in_transaction( :block_num, :trx_in_block )",
      block_num=block_num,
      trx_in_block=trx_in_block
    )

  async def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool):
    return await self._get_all(
      "SELECT * FROM get_ops_in_block( :block_num,  :only_virt, :include_reversible )",
      block_num=block_num,
      only_virt=only_virtual,
      include_reversible=include_reversible
    )

  async def get_transaction(self, trx_hash : bytes, include_reversible : bool ):
    return await self._get_all(
      "SELECT * FROM get_transaction( :trx_hash, :include_reversible )",
      trx_hash=trx_hash,
      include_reversible=include_reversible
    )

  async def enum_virtual_ops(self, filter : list, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool):
    return await self._get_all(
      "SELECT * FROM enum_virtual_ops( :filter ::INT[] , :block_range_begin, :block_range_end, :operation_begin, :limit, :include_reversible ) ORDER BY _operation_id",
      filter=filter,
      block_range_begin=block_range_begin,
      block_range_end=block_range_end,
      operation_begin=operation_begin,
      limit=limit,
      include_reversible=include_reversible
    )

  async def get_account_history(self, filter : list, account : str, start : int, limit : int, include_reversible : bool):
    return await self._get_all(
      "SELECT * FROM ah_get_account_history( :filter, :account, :start, :limit, :include_reversible )",
      filter=filter,
      account=account,
      start=start,
      limit=limit,
      include_reversible=include_reversible
    )

  async def get_irreversible_block_num(self) -> int:
    result = await self._get_all("SELECT hive.app_get_irreversible_block( 'account_history' ) as num")
    return result[0]['num']

  async def get_operation_id_types(self):
    ''' for tests only '''
    return await self._get_all("SELECT name, id FROM hive.operation_types")
