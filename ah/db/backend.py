from ah.db.objects import account_history, operation, ops_in_block, transaction, virtual_ops
from ah.db.queries import account_history_db_connector

class account_history_impl:
  def __translate_filter(self, input : int):
    if input:
      result = []
      for i in range(128):
        if input & (1 << i):
          result.append( i )
      return result
    else:
      return None


  async def get_ops_in_block( self, db, block_num : int, only_virtual : bool, include_reversible : bool) -> ops_in_block:
    api = account_history_db_connector(db)
    return ops_in_block( block_num, await api.get_ops_in_block(block_num, only_virtual, include_reversible) )

  async def get_transaction(self, db, trx_hash : str, include_reversible : bool ) -> transaction:
    api = account_history_db_connector(db)

    transaction_basic_info = await api.get_transaction( trx_hash.encode('ascii'), include_reversible )
    
    if len(transaction_basic_info) == 0: return dict()
    else: transaction_basic_info = dict(transaction_basic_info[0])

    operations = api.get_ops_in_transaction( transaction_basic_info['_block_num'], transaction_basic_info['_trx_in_block'] )

    transaction_basic_info['_signature'] = [ transaction_basic_info['_signature'] ]
    if transaction_basic_info['_multisig_number'] >= 1:
      additional_signatures = await api.get_multi_signatures_in_transaction( trx_hash )
      transaction_basic_info['_signature'].extend( [x[0] for x in additional_signatures] )

    transaction_basic_info['_value'] = [ operation( op[0] ) for op in await operations ]

    return transaction(trx_hash, transaction_basic_info)


  async def enum_virtual_ops(self, db, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool = False ) -> virtual_ops:
    api = account_history_db_connector(db)
    return virtual_ops( 
      await api.get_irreversible_block_num() if group_by_block else None,
      await api.enum_virtual_ops( 
        self.__translate_filter( filter ), 
        block_range_begin, 
        block_range_end, 
        operation_begin, 
        limit,
        include_reversible
      )
    )

  async def get_account_history(self, db, filter : int, account : str, start : int, limit : int, include_reversible : bool) -> account_history:
    api = account_history_db_connector(db)
    return account_history( 
      await api.get_account_history(
        self.__translate_filter( filter ), 
        account, 
        start, 
        limit,
        include_reversible
      )
    )
