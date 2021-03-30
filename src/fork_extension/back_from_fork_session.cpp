#include "back_from_fork_session.hpp"

#include "sql_commands.hpp"

#include "include/pq_utils/copy_tuples_session.hpp"
#include "include/pq_utils/db_client.hpp"
#include "include/pq_utils/transaction.hpp"
#include "include/psql_utils/postgres_includes.hpp"
#include "include/psql_utils/relation.hpp"

#include "include/exceptions.hpp"

#include <cassert>

using namespace std::string_literals;

namespace PsqlTools::ForkExtension {

BackFromForkSession::BackFromForkSession() try {
  m_transaction = PostgresPQ::DbClient::currentDatabase().startTransaction();
}
catch( std::exception& _exception ) {
  THROW_INITIALIZATION_ERROR( "Cannot start back from fork: "s + _exception.what() );
} catch( ... ) {
  THROW_INITIALIZATION_ERROR( "Cannot start back from fork because of unknown exception" );
}

BackFromForkSession::~BackFromForkSession() {
  assert( m_transaction );

  endCopySession();
  m_transaction->execute( PsqlTools::ForkExtension::Sql::EMPTY_TUPLES );
}

void
BackFromForkSession::backFromFork() {
  assert( m_transaction );

  fetchStoredTuples();

  for ( uint64_t row = 0u; row < SPI_processed; ++row ) {
    HeapTuple tuple_row = *(SPI_tuptable->vals + row);

    setCurrentlyProcessedRelation( tuple_row, SPI_tuptable->tupdesc );

    switch ( getOperationType( tuple_row, SPI_tuptable->tupdesc ) ) {
      case OperationType::INSERT:
        revertInsert( tuple_row, SPI_tuptable->tupdesc );
        break;
      case OperationType::DELETE:
        revertDelete( tuple_row, SPI_tuptable->tupdesc );
        break;
      case OperationType::UPDATE:
        revertUpdate( tuple_row, SPI_tuptable->tupdesc );
        break;
      default:
        assert( "Unsuported operation type" );
    }
  } // for each row
}

void
BackFromForkSession::fetchStoredTuples() {
  if (SPI_execute(PsqlTools::ForkExtension::Sql::GET_STORED_TUPLES, true, 0/*all rows*/ ) != SPI_OK_SELECT ) {
    THROW_RUNTIME_ERROR( "Cannot execute: "s + PsqlTools::ForkExtension::Sql::GET_STORED_TUPLES );
  }
}

void
BackFromForkSession::setCurrentlyProcessedRelation( HeapTuple _tuple, TupleDesc _tuple_desc ) {
  auto relation_name = getTableName( _tuple, _tuple_desc );

  if ( !m_processed_relation || m_processed_relation->getName() != relation_name ) {
    m_processed_relation = PsqlUtils::IRelation::create( relation_name );
  }
}

std::string
BackFromForkSession::getTableName( HeapTuple _tuple, TupleDesc _tupleDesc ) const {
  if ( _tuple == nullptr || _tupleDesc == nullptr ) {
    THROW_RUNTIME_ERROR( "Incorrect tuple pointer" );
  }

  auto table_name = SPI_getvalue( _tuple, SPI_tuptable->tupdesc, static_cast< int32_t >( Sql::TuplesTableColumns::TableName ) );
  if (  table_name == nullptr ) {
    THROW_RUNTIME_ERROR( "Cannot get table name from stored tuple"s );
  }

  return std::string( table_name );
}

OperationType
BackFromForkSession::getOperationType( HeapTuple _tuple, TupleDesc _tupleDesc ) const {
  if ( _tuple == nullptr || _tupleDesc == nullptr ) {
    THROW_RUNTIME_ERROR( "Incorrect tuple pointer" );
  }

  bool is_null( false );
  const auto operation_datum = SPI_getbinval(_tuple, _tupleDesc,
                                             static_cast< int32_t >( Sql::TuplesTableColumns::Operation ), &is_null);
  if (is_null) {
    THROW_RUNTIME_ERROR("No operation specified in tuples table");
  }

  switch (DatumGetInt16(operation_datum)) {
    case static_cast< uint16_t >( OperationType::DELETE ):
      return OperationType::DELETE;
    case static_cast< uint16_t >( OperationType::INSERT ):
      return OperationType::INSERT;
    case static_cast< uint16_t >( OperationType::UPDATE ):
      return OperationType::UPDATE;
    default:
      THROW_RUNTIME_ERROR("Unknown operation specified in tuples table");
  }

  assert( !"never reach this place" );
  return OperationType::INSERT; // to calm compiler
}

void
BackFromForkSession::revertInsert( HeapTuple _tuple, TupleDesc _tupleDesc ) {
  assert( m_processed_relation );
  assert( m_transaction );

  endCopySession();

  bool is_null( false );
  auto binary_value = SPI_getbinval( _tuple, _tupleDesc, static_cast< int32_t >( Sql::TuplesTableColumns::NewTuple ), &is_null );

  auto condition = m_processed_relation->createPkeyCondition(DatumGetByteaPP(binary_value));

  if ( condition.empty() ) {
    THROW_RUNTIME_ERROR( "No primary key condition for inserted tuple for table :"s + m_processed_relation->getName() );
  }

  auto remove_row_sql = "DELETE FROM "s + m_processed_relation->getName() + " WHERE "s + condition;
  m_transaction->execute( remove_row_sql );
}

void
BackFromForkSession::revertDelete( HeapTuple _tuple, TupleDesc _tupleDesc ) {
  assert( m_processed_relation );
  assert( m_transaction );

  setCurrentlyProcessedCopySession();

  bool is_null( false );
  auto binary_value = SPI_getbinval(_tuple, _tupleDesc, static_cast< int32_t >( Sql::TuplesTableColumns::OldTuple ), &is_null);
  if (is_null) {
    THROW_RUNTIME_ERROR( "Unexpect null column value in query: "s + PsqlTools::ForkExtension::Sql::GET_STORED_TUPLES );
  }

  assert( m_copy_session );
  m_copy_session->push_tuple(DatumGetByteaPP(binary_value) );
}

void
BackFromForkSession::revertUpdate( HeapTuple _tuple, TupleDesc _tupleDesc ) {
  assert( m_processed_relation );
  assert( m_transaction );

  endCopySession();

  bool is_null( false );
  auto new_tuple_value = SPI_getbinval(_tuple, _tupleDesc, static_cast< int32_t >( Sql::TuplesTableColumns::NewTuple ), &is_null);

  auto old_tuple_value = SPI_getbinval(_tuple, _tupleDesc, static_cast< int32_t >( Sql::TuplesTableColumns::OldTuple ), &is_null);

  auto condition = m_processed_relation->createPkeyCondition(DatumGetByteaPP(new_tuple_value));

  if (condition.empty()) {
    THROW_RUNTIME_ERROR("No primary key condition for inserted tuple in "s + m_processed_relation->getName() );
  }

  auto set_values = m_processed_relation->createRowValuesAssignment(DatumGetByteaPP(old_tuple_value));
  if ( set_values.empty() ) {
    THROW_RUNTIME_ERROR( "No values to set "s + m_processed_relation->getName() );
  }

  auto update_row = "UPDATE "s + m_processed_relation->getName()
    + " SET "s + set_values + " WHERE "s + condition;
  m_transaction->execute( update_row );
}

void
BackFromForkSession::endCopySession() {
  m_copy_session.reset();
}

void
BackFromForkSession::setCurrentlyProcessedCopySession() {
  assert( m_processed_relation );
  assert( m_transaction );

  if (!m_copy_session || m_copy_session->get_table_name() != m_processed_relation->getName() ) {
    endCopySession();
    m_copy_session = m_transaction->startCopyTuplesSession( m_processed_relation->getName(), {} );
  }
}


} // namespace PsqlTools::ForkExtension

