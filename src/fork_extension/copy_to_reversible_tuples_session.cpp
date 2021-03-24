#include "copy_to_reversible_tuples_session.hpp"

#include "sql_commands.hpp"

#include "include/exceptions.hpp"
#include "include/psql_utils/postgres_includes.hpp"
#include "include/pq_utils/copy_tuples_session.hpp"
#include "include/pq_utils/transaction.hpp"

#include <cassert>
#include <exception>
#include <vector>

namespace PsqlTools::ForkExtension {

  CopyToReversibleTuplesTable::CopyToReversibleTuplesTable( PostgresPQ::Transaction& _transaction )
  {
    m_copy_session = _transaction.startCopyTuplesSession(  TUPLES_TABLE_NAME, { "table_name", "operation", "tuple_old", "tuple_new" }  );

    if ( m_copy_session == nullptr ) {
      THROW_INITIALIZATION_ERROR( "Incorrect copy session ptr." );
    }
  }

  CopyToReversibleTuplesTable::~CopyToReversibleTuplesTable() {}

  void
  CopyToReversibleTuplesTable::push_delete(const std::string& _table_name, const HeapTupleData& _deleted_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_table_name( _table_name ); // table name
    push_operation( OperationType::DELETE );
    m_copy_session->push_tuple_as_next_column(_deleted_tuple, _tuple_desc ); // old tuple
    m_copy_session->push_null_field(); // new tuple
    push_id_field(); // id
  }

  void
  CopyToReversibleTuplesTable::push_insert(const std::string& _table_name, const HeapTupleData& _inserted_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_table_name( _table_name );
    push_operation( OperationType::INSERT );
    m_copy_session->push_null_field(); // old tuple - before insert there was no tuple
    m_copy_session->push_tuple_as_next_column( _inserted_tuple, _tuple_desc ); // new tuple
    push_id_field();
  }

  void
  CopyToReversibleTuplesTable::push_update( const std::string& _table_name, const HeapTupleData& _old_tuple, const HeapTupleData& _new_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_table_name( _table_name );
    push_operation( OperationType::UPDATE );
    m_copy_session->push_tuple_as_next_column( _old_tuple, _tuple_desc ); // old tuple
    m_copy_session->push_tuple_as_next_column( _new_tuple, _tuple_desc ); // new tuple
    push_id_field();
  }

  void
  CopyToReversibleTuplesTable::push_tuple_header() {
    static constexpr uint16_t number_of_columns = 4; // table, operation, prev, next (id is ommitted)
    m_copy_session->push_tuple_header( number_of_columns );
  }

  void
  CopyToReversibleTuplesTable::push_id_field() {
    //let the postgres to insert next serial value
    return;
  }

  void
  CopyToReversibleTuplesTable::push_table_name( const std::string& _table_name ) {
    uint32_t name_size = htonl( _table_name.size() );
    m_copy_session->push_data( &name_size, sizeof( uint32_t ) );
    m_copy_session->push_data( _table_name.c_str(), _table_name.size()  );
  }

  void
  CopyToReversibleTuplesTable::push_operation( OperationType _operation) {
    uint32_t operation_size = htonl( sizeof( uint16_t ) );
    auto operation = htons( static_cast<uint16_t>( _operation ) );
    m_copy_session->push_data( &operation_size, sizeof( uint32_t ) );
    m_copy_session->push_data( &operation, sizeof( uint16_t )  );
  }

} // namespace PsqlTools::ForkExtension
