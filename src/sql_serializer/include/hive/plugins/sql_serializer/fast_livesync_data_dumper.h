#pragma once

#include <hive/plugins/sql_serializer/livesync_data_dumper.h>

namespace hive::plugins::sql_serializer {

  class fast_livesync_data_dumper : public livesync_data_dumper {
  public:
    fast_livesync_data_dumper(
        const std::string& db_url
      , const appbase::abstract_plugin& plugin
      , hive::chain::database& chain_db
      , uint32_t operations_threads
      , uint32_t transactions_threads
      , uint32_t account_operation_threads
    );
    ~fast_livesync_data_dumper();

  private:
    void disable_reversible_indexes();
    void enable_reversible_indexes();
  };
} //namespace hive::plugins::sql_serializer