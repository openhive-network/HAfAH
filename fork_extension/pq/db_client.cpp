#include "include/pq/db_client.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"
#include "include/logger.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <exception>
#include <cassert>

namespace ForkExtension::PostgresPQ {

DbClient::DbClient() {
  auto database_name = get_database_name();
  if ( database_name.empty() ) {
    THROW_INITIALIZATION_ERROR( "Cannot get database name" );
  }

  // Because we use PQ only from postgress triggers/function we don't have to pass user and password
  std::string connection_string = "dbname=" + database_name;
  m_connection.reset( PQconnectdb( connection_string.c_str() ), PQfinish );

  if ( m_connection == nullptr ) {
    THROW_INITIALIZATION_ERROR( "Cannot connect to databse '" + database_name + "'" );
  }

  if (PQstatus(m_connection.get()) != CONNECTION_OK)
  {
    std::string error = "Failed connection to database " + database_name + " : " + PQerrorMessage(m_connection.get());
    m_connection.reset();
    THROW_INITIALIZATION_ERROR( error );
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
  // Don't care for the lifetime, it will be released together with whole psql client connection process
  ms_instance.reset( new DbClient() );

  /* If the PQclient has been disconected by the server, then we try to re-establish the connection once
   * If the connection is still not valid then the client methods will fail and throw exceptions which become visible on postgres log and consele
   * Each new trigger/function will try again to re-establish the connection
   */
  if ( PQstatus( ms_instance->m_connection.get() ) != CONNECTION_OK ) {
    LOG_WARNING( "PQclient was disconnected from the server and try to reconnect" );
    ms_instance.reset( new DbClient() );
  }

  return *ms_instance;
}

std::string
DbClient::get_database_name() const {
  Datum db_name = OidFunctionCall0( F_CURRENT_DATABASE );
  return DatumGetCString( db_name );
}

std::unique_ptr< DbClient > DbClient::ms_instance;

} // namespace ForkExtension::PostgresPQ


