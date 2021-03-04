#include "include/pq/db_client.hpp"

#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <exception>
#include <cassert>

namespace SecondLayer::PostgresPQ {

DbClient::DbClient(const std::string& _database, const std::string& _user, const std::string& _password) {
  std::string connection_string = std::string("dbname=") + _database + " user=" + _user + " password=" + _password + " port=5432" + " hostaddr=127.0.0.1";
  m_connection.reset( PQconnectdb( connection_string.c_str() ), PQfinish );

  if ( m_connection == nullptr ) {
    throw std::invalid_argument( "Cannot connect to databse '" + _database + "'" );
  }

  if (PQstatus(m_connection.get()) != CONNECTION_OK)
  {
    std::string error = std::string("Failed connection to database ") + _database + " : " + PQerrorMessage(m_connection.get());
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

} // namespace SecondLayer::PostgresPQ


