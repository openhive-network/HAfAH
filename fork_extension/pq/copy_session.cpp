#include "include/pq/copy_session.hpp"

#include "include/postgres_includes.hpp"
#include "include/exceptions.hpp"


#include <cassert>
#include <exception>
#include <limits>

using namespace std::string_literals;

namespace ForkExtension::PostgresPQ {

CopySession::CopySession( std::shared_ptr< PGconn > _connection, const std::string& _table_name )
  : m_connection( std::move(_connection) )
  , m_table_name( _table_name ) {
  if ( m_connection  == nullptr ) {
    THROW_INITIALIZATION_ERROR( "No connection to postgres" );
  }

  if ( _table_name.empty() ) {
    THROW_INITIALIZATION_ERROR( "Incorrect table name "s + _table_name  );
  }

  std::string binary_copy_cmd = "COPY " + _table_name + " FROM STDIN binary";
  std::shared_ptr< PGresult > open_session_result( PQexec( m_connection.get(), binary_copy_cmd.c_str() ), PQclear );

  if ( open_session_result == nullptr ) {
    auto pg_error_msg = PQerrorMessage( m_connection.get() );
    THROW_INITIALIZATION_ERROR( "Cannot execute sql command: "s + binary_copy_cmd.c_str() + " :"s  + pg_error_msg );
  }

  if ( PQresultStatus( open_session_result.get() ) != PGRES_COPY_IN ) {
    auto pg_error_msg = PQerrorMessage( m_connection.get() );
    THROW_INITIALIZATION_ERROR( "Cannot start copy to table: " + _table_name + " :"s + pg_error_msg );
  }
}

CopySession::~CopySession() {
  assert( m_connection );
  PQputCopyEnd( m_connection.get(), nullptr );
}

void
CopySession::push_data_internal( const char* _data, uint32_t _size ) const {
  assert( m_connection );

  if ( _size > std::numeric_limits< int32_t >::max() ) {
    THROW_RUNTIME_ERROR( "To much bytes to copy into table "s + m_table_name );
  }

  static constexpr auto COPY_SUCCESS = 1;
  const auto copy_result = PQputCopyData( m_connection.get(), const_cast< char* >( _data ), static_cast<int32_t>( _size ) );

  if ( copy_result != COPY_SUCCESS ) {
    THROW_RUNTIME_ERROR( "Cannot COPY data to table "s + m_table_name + " :" + PQerrorMessage( m_connection.get() ) );
  }
}

} // namespace ForkExtension::PostgresPQ

