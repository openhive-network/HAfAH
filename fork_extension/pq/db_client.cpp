#include "include/pq/db_client.hpp"

#include "include/postgres_includes.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <exception>
#include <cassert>

namespace SecondLayer::PostgresPQ {

DbClient::DbClient() {
  auto database_name = get_database_name();
  if ( database_name.empty() ) {
    throw std::runtime_error( "Cannot get database name" );
  }

  // Because we use PQ only form postgress triggers/function we don't have to pass user and password
  std::string connection_string = "dbname=" + database_name;
  m_connection.reset( PQconnectdb( connection_string.c_str() ), PQfinish );

  if ( m_connection == nullptr ) {
    throw std::invalid_argument( "Cannot connect to databse '" + database_name + "'" );
  }

  if (PQstatus(m_connection.get()) != CONNECTION_OK)
  {
    std::string error = "Failed connection to database " + database_name + " : " + PQerrorMessage(m_connection.get());
    m_connection.reset();
    throw std::runtime_error( error );
  }
}

std::unique_ptr< CopyToReversibleTuplesTable >
DbClient::startCopyToReversibleTuplesSession() {
  assert( m_connection );
  return std::unique_ptr< CopyToReversibleTuplesTable >( new CopyToReversibleTuplesTable( m_connection ) );
}

std::unique_ptr< CopyTuplesSession >
DbClient::startCopyTuplesSession( const std::string& _table_name ) {
  assert( m_connection );

  return std::unique_ptr< CopyTuplesSession >( new CopyTuplesSession( m_connection, _table_name ) );
}

DbClient::~DbClient() {

}

DbClient&
DbClient::get(){
  // Don't care for the lifetime, it will be freed with whole psql client connection process
  std::call_once( ms_dbclient_create_once, [](){ ms_instance.reset( new DbClient() ); } );
  assert( ms_instance );

  // TODO: check if connection is still valid ?
  return *ms_instance;
}

std::string
DbClient::get_database_name() const {
  Datum db_name = OidFunctionCall0( F_CURRENT_DATABASE );
  return DatumGetCString( db_name );
}

std::once_flag DbClient::ms_dbclient_create_once;
std::unique_ptr< DbClient > DbClient::ms_instance;

} // namespace SecondLayer::PostgresPQ


