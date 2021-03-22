#include "include/exceptions.hpp"

#include "include/pq/copy_to_reversible_tuples_session.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/transaction.hpp"

#include "include/operation_types.hpp"
#include "include/postgres_includes.hpp"
#include "include/relation_wrapper.hpp"
#include "include/sql_commands.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <mutex>
#include <string>

using ForkExtension::PostgresPQ::DbClient;
using ForkExtension::OperationType;
using ForkExtension::Sql::TuplesTableColumns;
using namespace std::string_literals;

extern "C" {
PG_FUNCTION_INFO_V1(back_from_fork);
}

namespace {
    bool IS_BACK_FROM_FORK_IN_PROGRESS = false;
}

namespace ForkExtension {

  bool isBackFromForkInProgress() {
    return IS_BACK_FROM_FORK_IN_PROGRESS;
  }

} // namespace ForkExtension

Datum back_from_fork([[maybe_unused]] PG_FUNCTION_ARGS) try {
  LOG_INFO("back_from_fork");

  IS_BACK_FROM_FORK_IN_PROGRESS = true;
  // TODO: needs C++ abstraction for SPI, otherwise evrywhere we will copy this
  SPI_connect();
  BOOST_SCOPE_EXIT_ALL() {
        SPI_finish();
        IS_BACK_FROM_FORK_IN_PROGRESS = false;
  };

  // TODO: change to prepared statements
  if (SPI_execute(ForkExtension::Sql::GET_STORED_TUPLES, true, 0/*all rows*/ ) != SPI_OK_SELECT ) {
    THROW_RUNTIME_ERROR( "Cannot execute: "s + ForkExtension::Sql::GET_STORED_TUPLES );
  }

  auto transaction = ForkExtension::PostgresPQ::DbClient::currentDatabase().startTransaction();
  std::unique_ptr< ForkExtension::PostgresPQ::CopyTuplesSession > copy_session;

  for ( uint64_t row =0; row < SPI_processed; ++row ) {
    HeapTuple tuple_row = *(SPI_tuptable->vals + row);
    bool is_null(false);

    auto table_name = SPI_getvalue(tuple_row, SPI_tuptable->tupdesc,
                                   static_cast< int32_t >( TuplesTableColumns::TableName ));
    if (!table_name) {
      THROW_RUNTIME_ERROR("Unexpect null column value in query: "s + ForkExtension::Sql::GET_STORED_TUPLES);
    }

    const auto operation_datum = SPI_getbinval(tuple_row, SPI_tuptable->tupdesc,
                                               static_cast< int32_t >( TuplesTableColumns::Operation ), &is_null);
    if (is_null) {
      THROW_RUNTIME_ERROR("No operation specified in tuples table");
    }

    switch (DatumGetInt16(operation_datum)) {
      case static_cast< uint16_t >( OperationType::DELETE ): {
        if (!copy_session || copy_session->get_table_name() != table_name) {
          copy_session = transaction->startCopyTuplesSession(table_name);
        }

        auto binary_value = SPI_getbinval(tuple_row, SPI_tuptable->tupdesc,
                                          static_cast< int32_t >( TuplesTableColumns::OldTuple ), &is_null);
        if (is_null) {
          THROW_RUNTIME_ERROR( "Unexpect null column value in query: "s + ForkExtension::Sql::GET_STORED_TUPLES );
        }
        copy_session->push_tuple(DatumGetByteaPP(binary_value) );
        break;
      } // case OperationType::DELETE
      case static_cast< uint16_t >( OperationType::INSERT ): {
        if ( copy_session ) { // We need to break pending copy session
          copy_session.reset();
        }

        auto binary_value = SPI_getbinval(tuple_row, SPI_tuptable->tupdesc,
                                          static_cast< int32_t >( TuplesTableColumns::NewTuple ), &is_null);
        Relation raw_rel;
        raw_rel = heap_openrv(makeRangeVar(NULL, table_name, -1), AccessShareLock);
        if (raw_rel == nullptr) {
          THROW_RUNTIME_ERROR("Cannot open relation "s + table_name);
        }
        ForkExtension::RelationWrapper rel(*raw_rel);
        auto condition = rel.createPkeyCondition(DatumGetByteaPP(binary_value));

        if ( condition.empty() ) {
          THROW_RUNTIME_ERROR( "No primary key condition for inserted tuple in " );
        }
        heap_close(raw_rel, NoLock);
        auto remove_row_sql = "DELETE FROM "s + table_name + " WHERE "s + condition;
        transaction->execute( remove_row_sql );
        break;
      }
      case static_cast< uint16_t >( OperationType::UPDATE ): {
        if (copy_session) { // We need to break pending copy session
          copy_session.reset();
        }

        auto new_tuple_value = SPI_getbinval(tuple_row, SPI_tuptable->tupdesc,
                                             static_cast< int32_t >( TuplesTableColumns::NewTuple ), &is_null);

        auto old_tuple_value = SPI_getbinval(tuple_row, SPI_tuptable->tupdesc,
                                             static_cast< int32_t >( TuplesTableColumns::OldTuple ), &is_null);

        Relation raw_rel;
        raw_rel = heap_openrv(makeRangeVar(NULL, table_name, -1), AccessShareLock);
        if (raw_rel == nullptr) {
          THROW_RUNTIME_ERROR("Cannot open relation "s + table_name);
        }
        ForkExtension::RelationWrapper rel(*raw_rel);
        auto condition = rel.createPkeyCondition(DatumGetByteaPP(new_tuple_value));

        if (condition.empty()) {
          THROW_RUNTIME_ERROR("No primary key condition for inserted tuple in ");
        }
        heap_close(raw_rel, NoLock);
        auto remove_row_sql = "DELETE FROM "s + table_name + " WHERE "s + condition;
        transaction->execute(remove_row_sql);

        if (!copy_session || copy_session->get_table_name() != table_name) {
          copy_session = transaction->startCopyTuplesSession(table_name);
        }
        copy_session->push_tuple(DatumGetByteaPP(old_tuple_value));
        break;
      }
      default: {
        THROW_RUNTIME_ERROR("Unknow operation type in tuples table");
      }
    }
  } // for each tuple

  copy_session.reset(); // if any copy in progress
  transaction->execute( ForkExtension::Sql::EMPTY_TUPLES );

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


