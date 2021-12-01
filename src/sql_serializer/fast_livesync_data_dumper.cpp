#include <hive/plugins/sql_serializer/fast_livesync_data_dumper.h>

namespace hive { namespace plugins { namespace sql_serializer {
  fast_livesync_data_dumper::fast_livesync_data_dumper(
      const std::string& db_url
    , const appbase::abstract_plugin& plugin
    , hive::chain::database& chain_db
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads
  )
    : livesync_data_dumper(
          db_url
        , plugin
        , chain_db
        , operations_threads
        , transactions_threads
        , account_operation_threads
    )
  {
    ilog( "fast livesync dumper created" );
    disconnect_irreversible_event();
    disable_reversible_indexes();
  }

  fast_livesync_data_dumper::~fast_livesync_data_dumper() {
    enable_reversible_indexes();
    ilog( "fast livesync dumper closed" );
  }

  void fast_livesync_data_dumper::disable_reversible_indexes() {
    ilog( "Disabling reversible idexes..." );
    auto transaction = get_transaction_controller().openTx();
    std::string command = "SELECT hive.disable_indexes_of_reversible()";
    transaction->exec( command );
    transaction->commit();
    ilog( "Reversible idexes disabled" );
  }

<<<<<<< HEAD
  void fast_livesync_data_dumper::enable_reversible_indexes() {
    return;
=======
  void fast_livesync_data_dumper::eqnable_reversible_indexes() {
>>>>>>> 99e6aa8... fix bugs with fasts live sync
    ilog( "Enabling reversible idexes..." );
    auto transaction = get_transaction_controller().openTx();
    std::string command = "SELECT hive.enable_indexes_of_reversible()";
    transaction->exec( command );
    transaction->commit();
    ilog( "Reversible idexes enabled" );
  }
}}} // namespace hive::plugins::sql_serializer

