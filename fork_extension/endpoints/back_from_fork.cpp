#include "include/exceptions.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"
#include "include/postgres_includes.hpp"
#include "include/sql_commands.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <mutex>
#include <string>

using ForkExtension::PostgresPQ::DbClient;
using namespace std::string_literals;

extern "C" {
PG_FUNCTION_INFO_V1(back_from_fork);
}

Datum back_from_fork([[maybe_unused]] PG_FUNCTION_ARGS) try {
  LOG_INFO("back_from_fork");

  // TODO: needs C++ abstraction for SPI, otherwise evrywhere we will copy this
  SPI_connect();
  BOOST_SCOPE_EXIT_ALL() {
        SPI_finish();
  };

  // TODO: change to prepared statements
  if (SPI_execute(ForkExtension::Sql::GET_STORED_TUPLES, true, 0/*all rows*/ ) != SPI_OK_SELECT ) {
    THROW_RUNTIME_ERROR( "Cannot execute: "s + ForkExtension::Sql::GET_STORED_TUPLES );
  }


  // TODO: add structure which describe schema
  auto copy_session = DbClient::get().startCopyTuplesSession( "dst_table" );

  for ( uint64_t row =0; row < SPI_processed; ++row ) {
    HeapTuple tuple_row = *(SPI_tuptable->vals + row);
    bool is_null( false );
    auto binary_value = SPI_getbinval( tuple_row, SPI_tuptable->tupdesc, 1, &is_null );
    if ( is_null ) {
      THROW_RUNTIME_ERROR( "Unexpect null column value in query: "s + ForkExtension::Sql::GET_STORED_TUPLES );
    }

    copy_session->push_tuple( DatumGetByteaPP( binary_value ) );
  }

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


