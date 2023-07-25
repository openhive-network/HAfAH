#include <hive/plugins/sql_serializer/tables_descriptions.h>

namespace hive{ namespace plugins{ namespace sql_serializer {

  const char hive_blocks::TABLE[] = "hive.blocks";
  const char hive_blocks::COLS[] = "num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger ";

  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  const char hive_transactions_multisig::TABLE[] = "hive.transactions_multisig";
  const char hive_transactions_multisig::COLS[] = "trx_hash, signature";

  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::TABLE[] = "hive.operations";
  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::COLS[] = "id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary";

  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::TABLE[] = "hive.operations";
  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::COLS[] = "id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary";

  const char hive_accounts::TABLE[] = "hive.accounts";
  const char hive_accounts::COLS[] = "id, name, block_num";

  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::COLS[] = "block_num, account_id, account_op_seq_no, operation_id, op_type_id";

  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::COLS[] = "block_num, account_id, account_op_seq_no, operation_id, op_type_id";

  const char hive_applied_hardforks::TABLE[] = "hive.applied_hardforks";
  const char hive_applied_hardforks::COLS[] = "hardfork_num, block_num, hardfork_vop_id";


}}} // namespace hive::plugins::sql_serializer


