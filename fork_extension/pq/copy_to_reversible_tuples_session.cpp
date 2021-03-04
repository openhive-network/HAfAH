#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <cassert>
#include <exception>
#include <vector>

#include <arpa/inet.h>

extern "C" {
#include <postgres.h>
#include <fmgr.h>
#include <commands/trigger.h>
} // extern "C"

namespace SecondLayer::PostgresPQ {
    int32_t CopyToReversibleTuplesTable::m_tuple_id = 0;

    CopyToReversibleTuplesTable::CopyToReversibleTuplesTable( std::shared_ptr< pg_conn > _connection )
  : CopyTuplesSession( _connection, "tuples" )
  {
  }

  CopyToReversibleTuplesTable::~CopyToReversibleTuplesTable() {}

  void
  CopyToReversibleTuplesTable::push_insert( const std::string& _table_name, const HeapTupleData& _new_tuple, const TupleDesc& _tuple_desc ) {
    push_tuple_header();
    push_id_field(); // id
    push_null_field(); // table name
    push_null_field(); // prev tuple
    push_tuple_as_next_column( _new_tuple, _tuple_desc );
    ++m_tuple_id;
  }

  void
  CopyToReversibleTuplesTable::push_tuple_header() {
    static constexpr uint16_t number_of_columns = 4; // id, table, prev, next
    CopyTuplesSession::push_tuple_header( number_of_columns );
  }

  void
  CopyToReversibleTuplesTable::push_id_field() {
    static uint32_t id_size = htonl( sizeof( uint32_t ) );
    push_data( reinterpret_cast< char* >( &id_size ), sizeof( uint32_t ) );
    auto tuple_id = htonl( m_tuple_id );
    push_data( reinterpret_cast< char* >( &tuple_id ), sizeof( uint32_t ) );
  }

} // namespace SecondLayer::PostgresPQ
