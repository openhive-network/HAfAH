#include <boost/test/unit_test.hpp>

#include "mock/pq_mock.hpp"
#include "mock/postgres_mock.hpp"

#include "include/pq/db_client.hpp"

using ::testing::Return;

BOOST_AUTO_TEST_CASE( positivie_client_connect, *boost::unit_test::disabled() )
{
  auto pq_mock = PqMock::create_and_get();
  auto postgres_mock = PostgresMock::create_and_get();

  // 1. get database name
  auto db_name_datum = CStringGetDatum( "test_db" );
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  EXPECT_CALL( *postgres_mock, OidFunctionCall0Coll( F_CURRENT_DATABASE, InvalidOid ) )
    .Times(1)
    .WillOnce( Return( db_name_datum ) )
  ;

  // 2. connect to database
  EXPECT_CALL( *pq_mock, PQconnectdb( ::testing::StrEq( "dbname=test_db" ) ) )
          .Times(1)
          .WillOnce( Return( connection_ptr ) )
  ;

  // 3. check status
  EXPECT_CALL( *pq_mock, PQstatus( connection_ptr ) )
          .WillRepeatedly( Return( CONNECTION_OK ) )
  ;

  // 4. disconnect when the client is destroyed
  EXPECT_CALL( *pq_mock, PQfinish( connection_ptr ) )
          .Times(1)
  ;
  {
    ForkExtension::PostgresPQ::DbClient::get();
  }
}