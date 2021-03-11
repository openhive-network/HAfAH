#include "include/initializer.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"
#include "include/sql_commands.hpp"

#include "gen/git_version.hpp"

#include <boost/scope_exit.hpp>

#include <string>

#include <unistd.h>

using namespace std::string_literals;

namespace ForkExtension {
  Initializer::Initializer() try {
    LOG_WARNING( "Initialize hive fork extension ver.: %s pid: %d", GIT_REVISION, getpid() );

    initialize_tuples_table();
    initialize_function( BACK_FROM_FORK_FUNCTION, "void" );
    initialize_function( ON_TABLE_CHANGE_FUNCTION, "trigger" );
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
      THROW_RUNTIME_ERROR( "Cannot create tuples table : "s + Sql::CREATE_TUPLES_TABLE );
    }

    LOG_INFO( "The " TUPLES_TABLE_NAME "table is initialized" );
  }

  void
  Initializer::initialize_function( const std::string& _function_name, const std::string& _sql_return_type ) const {
    if ( function_exists( _function_name ) ) {
      LOG_INFO( "The '%s' function already initialized", _function_name.c_str() );
      return;
    }

    SPI_connect();
    BOOST_SCOPE_EXIT_ALL() {
                               SPI_finish();
                           };

    const auto execute_cmd
      = "CREATE FUNCTION "s + _function_name + "() RETURNS "s + _sql_return_type + " AS '$libdir/plugins/libfork_extension.so', '"s + _function_name + "' LANGUAGE C"s;
    if ( SPI_execute( execute_cmd.c_str(), false, 0 ) != SPI_OK_UTILITY ) {
      THROW_RUNTIME_ERROR( "Cannot create function: "s + _function_name );
    }

    LOG_INFO( "The %s function is initialized", _function_name.c_str() );
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
