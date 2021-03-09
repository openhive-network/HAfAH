#include "include/initializer.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"
#include "include/sql_commands.hpp"

#include "gen/git_version.hpp"

#include <boost/scope_exit.hpp>

#include <string>

using namespace std::string_literals;

namespace ForkExtension {
  Initializer::Initializer() try {
    LOG_WARNING( "Initialize hive fork extension ver.: " GIT_REVISION );

    initialize_tuples_table();
    initialize_back_from_fork_function();
  }
  catch ( std::exception& _exception ) {
    LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  }
  catch( ... ) {
    LOG_ERROR( "Unhandled unknown exception" );
  }

  void
  Initializer::initialize_tuples_table() const {
    SPI_connect();
    BOOST_SCOPE_EXIT_ALL() {
      SPI_finish();
    };

    if ( SPI_execute( Sql::CREATE_TUPLES_TABLE, false, 0 ) != SPI_OK_UTILITY ) {
      THROW_RUNTIME_ERROR( "Cannot create tuples table: "s + Sql::CREATE_TUPLES_TABLE );
    }

    LOG_INFO( "The " TUPLES_TABLE_NAME "table is initialized" );
  }

  void
  Initializer::initialize_back_from_fork_function() const {
    if ( function_exists(BACK_FROM_FORK_FUNCTION) ) {
      LOG_INFO( "The " BACK_FROM_FORK_FUNCTION "function already initialized" );
      return;
    }


    SPI_connect();
    BOOST_SCOPE_EXIT_ALL() {
      SPI_finish();
    };

    if ( SPI_execute( Sql::CREATE_BACK_FROM_FORK_FUNCTION, false, 0 ) != SPI_OK_UTILITY ) {
      THROW_RUNTIME_ERROR( "Cannot create function: "s + BACK_FROM_FORK_FUNCTION );
    }

    LOG_INFO( "The " BACK_FROM_FORK_FUNCTION " function is initialized" );
  }

  bool
  Initializer::function_exists( const std::string& _function_name ) const {
    SPI_connect();
    BOOST_SCOPE_EXIT_ALL() {
      SPI_finish();
    };

    if ( SPI_execute( ( "SELECT * FROM pg_proc WHERE proname = '" + _function_name + "'" ).c_str(), true, 1 ) != SPI_OK_SELECT ) {
      THROW_RUNTIME_ERROR( "Cannot check if function "s + _function_name + " exists" );
    }

    return SPI_processed == 1;
  }
} // namespace ForkExtension


