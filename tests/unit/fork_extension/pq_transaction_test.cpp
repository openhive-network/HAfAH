#include <boost/test/unit_test.hpp>

#include "mock/pq_mock.hpp"
#include "mock/postgres_mock.hpp"

#include "include/pq/transaction.hpp"
#include "include/exceptions.hpp"

using ::testing::Return;

BOOST_AUTO_TEST_SUITE( pq_transaction )

BOOST_AUTO_TEST_CASE( positivie_client_connect )
{
  auto pq_mock = PqMock::create_and_get();

  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );
  PGresult* result_ptr( reinterpret_cast< PGresult* >( 0xAAAAFFFFFFFFFFFF ) );

  // 1. execute BEGIN TRANSACTION
  EXPECT_CALL( *pq_mock, PQexec( connection_ptr, ::testing::StrEq( "BEGIN TRANSACTION" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
  ;

  // 2. check status
  EXPECT_CALL( *pq_mock, PQresultStatus( result_ptr ) )
          .Times(2)
          .WillOnce( Return( PGRES_COMMAND_OK ) ) // for c_tor
          .WillOnce( Return( PGRES_COMMAND_OK ) ) // for d_tor
  ;

  // 3. execute COMMIT
  EXPECT_CALL( *pq_mock, PQexec( connection_ptr, ::testing::StrEq( "COMMIT" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
  ;

  ForkExtension::PostgresPQ::Transaction object_uder_test( connection );
}

BOOST_AUTO_TEST_CASE( negative_client_cannot_start_transaction )
{
  auto pq_mock = PqMock::create_and_get_nice();

  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );
  PGresult* result_ptr( reinterpret_cast< PGresult* >( 0xAAAAFFFFFFFFFFFF ) );

  // 1. execute BEGIN TRANSACTION
  EXPECT_CALL( *pq_mock, PQexec( connection_ptr, ::testing::StrEq( "BEGIN TRANSACTION" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
          ;

  // 2. check status
  EXPECT_CALL( *pq_mock, PQresultStatus( result_ptr ) )
          .Times(1)
          .WillOnce( Return( PGRES_FATAL_ERROR ) ) // for c_tor
          ;

  BOOST_CHECK_THROW(
      ForkExtension::PostgresPQ::Transaction object_uder_test( connection )
    , ForkExtension::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( negative_client_null_connection )
{
  BOOST_CHECK_THROW(
          ForkExtension::PostgresPQ::Transaction object_uder_test( nullptr )
  , ForkExtension::ObjectInitializationException
  );
}


BOOST_AUTO_TEST_SUITE_END()