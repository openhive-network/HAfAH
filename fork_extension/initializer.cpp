#include "include/initializer.hpp"

#include "include/postgres_includes.hpp"
#include "include/logger.hpp"

#include "gen/git_version.hpp"

#include <boost/scope_exit.hpp>

#include <string>


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
  std::string table_sql = "CREATE TABLE IF NOT EXISTS tuples(id integer, table_name text, tuple_prev bytea, tuple_old bytea)";

    SPI_connect();
    BOOST_SCOPE_EXIT_ALL() {
      SPI_finish();
    };

    if ( SPI_execute( table_sql.c_str(), false, 0 ) != SPI_OK_UTILITY ) {
      throw std::runtime_error( "Cannot create tuples table: " + table_sql );
    }
  }
} // namespace ForkExtension


