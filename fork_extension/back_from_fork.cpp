#include "include/back_from_fork.h"

#include "include/logger.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"
#include "include/postgres_includes.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <mutex>
#include <string>

using ForkExtension::PostgresPQ::DbClient;

Datum back_from_fork([[maybe_unused]] PG_FUNCTION_ARGS) try {
  LOG_INFO("back_from_fork");

  SPI_connect();
  BOOST_SCOPE_EXIT_ALL() {
        SPI_finish();
  };

  // TODO: change to prepared statements
  std::string get_stored_tuple = "SELECT tuple_old FROM tuples ORDER BY id DESC";
  if ( SPI_execute( get_stored_tuple.c_str(), true, 0/*all rows*/ ) != SPI_OK_SELECT ) {
    throw std::runtime_error( "Cannot execute: " + get_stored_tuple );
  }


  // TODO: add structure which describe schema
  auto copy_session = DbClient::get().startCopyTuplesSession( "dst_table" );

  for ( uint64_t row =0; row < SPI_processed; ++row ) {
    HeapTuple tuple_row = *(SPI_tuptable->vals + row);
    bool is_null( false );
    auto binary_value = SPI_getbinval( tuple_row, SPI_tuptable->tupdesc, 1, &is_null );
    if ( is_null ) {
      throw std::runtime_error( "Unexpect null column value in query: " + get_stored_tuple );
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


