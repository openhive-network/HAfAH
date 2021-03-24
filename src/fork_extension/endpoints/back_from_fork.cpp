#include "include/exceptions.hpp"

#include "back_from_fork_session.hpp"
#include "operation_types.hpp"
#include "sql_commands.hpp"

#include "include/pq_utils/copy_tuples_session.hpp"
#include "include/pq_utils/db_client.hpp"
#include "include/pq_utils/transaction.hpp"

#include "include/psql_utils/postgres_includes.hpp"
#include "include/psql_utils/relation.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <mutex>
#include <string>

using PsqlTools::PostgresPQ::DbClient;
using PsqlTools::ForkExtension::OperationType;
using PsqlTools::ForkExtension::Sql::TuplesTableColumns;
using namespace std::string_literals;

extern "C" {
PG_FUNCTION_INFO_V1(back_from_fork);
}

namespace {
    bool IS_BACK_FROM_FORK_IN_PROGRESS = false;
}

namespace PsqlTools::ForkExtension {

  bool isBackFromForkInProgress() {
    return IS_BACK_FROM_FORK_IN_PROGRESS;
  }

} // namespace PsqlTools::ForkExtension

Datum back_from_fork([[maybe_unused]] PG_FUNCTION_ARGS) try {
  LOG_INFO("Called 'back_from_fork'");

  IS_BACK_FROM_FORK_IN_PROGRESS = true;

  BOOST_SCOPE_EXIT_ALL() {
        IS_BACK_FROM_FORK_IN_PROGRESS = false;
  };

  PsqlTools::ForkExtension::BackFromForkSession back_from_fork;
  back_from_fork.backFromFork();

  PG_RETURN_VOID();
} //TODO: catches repeated with trigger, fix it
catch ( std::exception& _exception ) {
  LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  return 0;
}
catch( ... ) {
  LOG_ERROR( "Unhandled unknown exception" );
  return 0;
}


