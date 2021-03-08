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

    LOG_INFO( "The 'tuples' table is initialized" );
  }
} // namespace ForkExtension


