from ah.db.objects import account_history, operation, ops_in_block, transaction, virtual_ops
from ah.db.connection import Db
from ah.db.queries import account_history_db_connector

class account_history_impl:
  def __init__(self, db_address):
      self.db = Db(db_address)
      self.api = account_history_db_connector(self.db)
      self.translation_map = {
        0x000001: "fill_convert_request_operation",
        0x000002: "author_reward_operation",
        0x000004: "curation_reward_operation",
        0x000008: "comment_reward_operation",
        0x000010: "liquidity_reward_operation",
        0x000020: "interest_operation",
        0x000040: "fill_vesting_withdraw_operation",
        0x000080: "fill_order_operation",
        0x000100: "shutdown_witness_operation",
        0x000200: "fill_transfer_from_savings_operation",
        0x000400: "hardfork_operation",
        0x000800: "comment_payout_update_operation",
        0x001000: "return_vesting_delegation_operation",
        0x002000: "comment_benefactor_reward_operation",
        0x004000: "producer_reward_operation",
        0x008000: "clear_null_account_balance_operation",
        0x010000: "proposal_pay_operation",
        0x020000: "sps_fund_operation",
        0x040000: "hardfork_hive_operation",
        0x080000: "hardfork_hive_restore_operation",
        0x100000: "delayed_voting_operation",
        0x200000: "consolidate_treasury_balance_operation",
        0x400000: "effective_comment_vote_operation",
        0x800000: "ineffective_delete_comment_operation",
        0x1000000: "sps_convert_operation"
      }


  def __translate_filter(self, input : int):
    def __fetch_ids():
      pass
      # self.translation_map = { row[0]: row[1] for row in self.api.get_operation_ids( list(self.translation_map.items()) ) }
    # if isinstance(self.translation_map[1], str):
      # self.__fetch_ids()
    result = []
    if input:
      print(input)
      for i in range(128):
        if input & (1 << i):
          result.append( i )
    return result


  async def get_ops_in_block( self, block_num : int, only_virtual : bool, include_reversible : bool) -> ops_in_block:
    return ops_in_block( block_num, await self.api.get_ops_in_block(block_num, only_virtual, include_reversible) )

  async def get_transaction(self, trx_hash : str, include_reversible : bool ) -> transaction:
    transaction_basic_info = await self.api.get_transaction( trx_hash.encode('ascii'), include_reversible )
    
    if len(transaction_basic_info) == 0: return dict()
    else: transaction_basic_info = dict(transaction_basic_info[0])

    operations = self.api.get_ops_in_transaction( transaction_basic_info['_block_num'], transaction_basic_info['_trx_in_block'] )

    transaction_basic_info['_signature'] = [ transaction_basic_info['_signature'] ]
    if transaction_basic_info['_multisig_number'] >= 1:
      additional_signatures = await self.api.get_multi_signatures_in_transaction( trx_hash )
      transaction_basic_info['_signature'].extend( [x[0] for x in additional_signatures] )

    transaction_basic_info['_value'] = [ operation( op[0] ) for op in await operations ]

    return transaction(trx_hash, transaction_basic_info)


  async def enum_virtual_ops(self, filter : int, block_range_begin : int, block_range_end : int, operation_begin : int, limit : int, include_reversible : bool, group_by_block : bool = False ) -> virtual_ops:
    return virtual_ops( 
      self.api.get_irreversible_block_num() if group_by_block else None,
      await self.api.enum_virtual_ops( 
        self.__translate_filter( filter ), 
        block_range_begin, 
        block_range_end, 
        operation_begin, 
        limit,
        include_reversible
      )
    )

  async def get_account_history(self, filter : int, account : str, start : int, limit : int, include_reversible : bool) -> account_history:
    return account_history( 
      await self.api.get_account_history(
        self.__translate_filter( filter ), 
        account, 
        start, 
        limit,
        include_reversible
      )
    )
