#include "include/back_from_fork.h"

#include "include/postgres_common.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <mutex>
#include <string>

extern "C" {
#include <executor/spi.h>
#include <libpq-fe.h>
#include <utils/rel.h>
#include <utils/tuplestore.h>
}


Datum
back_from_fork(PG_FUNCTION_ARGS) try {
  elog(WARNING, "back_from_fork");

  SPI_connect();
  BOOST_SCOPE_EXIT_ALL() {
        SPI_finish();
  };

  // TODO: change to prepared statements
  std::string get_stored_tuple = "SELECT tuple_old FROM tuples ORDER BY id DESC";
  if ( SPI_execute( get_stored_tuple.c_str(), true, 0/*all rows*/ ) != SPI_OK_SELECT ) {
    throw std::runtime_error( "Cannot execute: " + get_stored_tuple );
  }

  std::call_once( DB_CLIENT_ONCE_FLAG, [](){ DB_CLIENT.reset( new SecondLayer::PostgresPQ::DbClient( "test", "marcin", "marcin" ) ); } );
  // TODO: add structure which describe schema
  auto copy_session = DB_CLIENT->startCopyTuplesSession( "blocks_copy" );

  for ( uint64_t row =0; row < SPI_processed; ++row ) {
    HeapTuple tuple_row = *(SPI_tuptable->vals + row);
    bool is_null( false );
    auto binary_value = SPI_getbinval( tuple_row, SPI_tuptable->tupdesc, 1, &is_null );
    if ( is_null ) {
      throw std::runtime_error( "Unexpect null column value in query" + get_stored_tuple );
    }

    copy_session->push_tuple( DatumGetByteaPP( binary_value ) );
  }

  // TODO: check if connection is still valid
  // TODO: copy with trigger code, fix it
  std::call_once( DB_CLIENT_ONCE_FLAG, [](){ DB_CLIENT.reset( new SecondLayer::PostgresPQ::DbClient( "test", "marcin", "marcin" ) ); } );
  assert( DB_CLIENT );

  PG_RETURN_VOID();
} //TODO: catches repeated with trigger, fix it
catch ( std::exception& _exception ) {
  ereport(
          ERROR,
          (errcode(ERRCODE_TRIGGERED_ACTION_EXCEPTION), errmsg("Unhandled exception: %s", _exception.what()))
  );
  return 0;
}
catch( ... ) {
  ereport(
          ERROR,
          (errcode(ERRCODE_TRIGGERED_ACTION_EXCEPTION), errmsg("Unhandled unknown exception"))
  );
  return 0;
}


