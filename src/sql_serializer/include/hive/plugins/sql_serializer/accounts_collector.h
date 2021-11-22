#pragma once

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>

#include <hive/chain/util/impacted.hpp>

#include <map>
#include <vector>

namespace hive::plugins::sql_serializer {
  struct account_info
    {
    account_info(int id, unsigned int operation_count) : _id(id), _operation_count(operation_count) {}

    /// Account id
    int _id;
    unsigned int _operation_count;
    };

  using account_cache_t = std::unordered_map<std::string, account_info>;

  struct accounts_collector
    {
    typedef void result_type;
    using account_data_container_t = std::vector<PSQL::processing_objects::account_data_t>;

    accounts_collector(
        account_cache_t* known_accounts
      , int* next_account_id
      , account_data_container_t* newAccounts
      , int32_t block_number
      )
      :
      _known_accounts(known_accounts),
      _next_account_id(*next_account_id),
      _new_accounts(newAccounts),
      _processed_operation(nullptr),
      _block_number( block_number )
    {
    }

    void collect(const hive::protocol::operation& op)
    {
      _processed_operation = &op;

      _processed_operation->visit(*this);

      _processed_operation = nullptr;
    }

    private:
      template<int64_t N, typename... Ts>
      friend struct fc::impl::storage_ops;

    template< typename T >
    void operator()(const T& v) { }

    void operator()(const hive::protocol::account_create_operation& op)
    {
      on_new_account(op.new_account_name);
    }

    void operator()(const hive::protocol::account_create_with_delegation_operation& op)
    {
      on_new_account(op.new_account_name);
    }

    void operator()(const hive::protocol::pow_operation& op)
    {
      if(_known_accounts->find(op.get_worker_account()) == _known_accounts->end())
        on_new_account(op.get_worker_account());
    }

    void operator()(const hive::protocol::pow2_operation& op)
    {
      flat_set<hive::protocol::account_name_type> newAccounts;
      hive::protocol::operation packed_op(op);
      hive::app::operation_get_impacted_accounts(packed_op, newAccounts);

      for(const auto& account_id : newAccounts)
      {
        if(_known_accounts->find(account_id) == _known_accounts->end())
          on_new_account(account_id);
      }
    }

    void operator()(const hive::protocol::create_claimed_account_operation& op)
    {
      on_new_account(op.new_account_name);
    }

    private:
      void on_new_account(const hive::protocol::account_name_type& name)
      {
        ++_next_account_id;
        _known_accounts->emplace(std::string(name), account_info(_next_account_id, 0));
        _new_accounts->emplace_back(_next_account_id, std::string(name), _block_number);
      }

    private:
      account_cache_t* _known_accounts;
      int& _next_account_id;
      account_data_container_t* _new_accounts;
      const hive::protocol::operation* _processed_operation;
      int32_t _block_number;
    };

} // namespace hive::plugins::sql_serializer