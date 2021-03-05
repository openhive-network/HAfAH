#include "include/pq/copy_session.hpp"

#include "include/postgres_includes.hpp"

#include <cassert>
#include <exception>
#include <limits>

namespace SecondLayer::PostgresPQ {

CopySession::CopySession( std::shared_ptr< PGconn > _connection, const std::string& _table_name )
  : m_connection( std::move(_connection) )
  , m_table_name( _table_name ) {
  if ( m_connection  == nullptr ) {
    throw std::invalid_argument( "No connection to postgres" );
  }

  if ( _table_name.empty() ) {
    throw std::invalid_argument( "Incorrect table name" );
  }

  std::string binary_copy_cmd = "COPY " + _table_name + " FROM STDIN binary";
  std::shared_ptr< PGresult > open_session_result( PQexec( m_connection.get(), binary_copy_cmd.c_str() ), PQclear );

  if ( open_session_result == nullptr ) {
    auto pg_error_msg = PQerrorMessage( m_connection.get() );
    throw std::runtime_error( std::string("Cannot execute sql command: ") + binary_copy_cmd + " :" + pg_error_msg );
  }

  if ( PQresultStatus( open_session_result.get() ) != PGRES_COPY_IN ) {
    auto pg_error_msg = PQerrorMessage( m_connection.get() );
    throw std::runtime_error( std::string("Cannot start copy to table: ") + _table_name + " :" + pg_error_msg );
  }
}

CopySession::~CopySession() {
  assert( m_connection );
  PQputCopyEnd( m_connection.get(), nullptr );
}

void
CopySession::push_data( const char* _data, uint32_t _size ) const {
  assert( m_connection );

  if ( _size > std::numeric_limits< int32_t >::max() ) {
    throw std::invalid_argument( "To much bytes to copy into table " + m_table_name );
  }

  static constexpr auto COPY_SUCCESS = 1;
  const auto copy_result = PQputCopyData( m_connection.get(), const_cast< char* >( _data ), static_cast<int32_t>( _size ) );

  if ( copy_result != COPY_SUCCESS ) {
    throw std::runtime_error( std::string("Cannot COPY data to table ") + m_table_name + " :" + PQerrorMessage( m_connection.get() ) );
  }
}

} // namespace SecondLayer::PostgresPQ

