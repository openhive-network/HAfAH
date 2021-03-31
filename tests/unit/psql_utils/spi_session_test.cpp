#include <boost/test/unit_test.hpp>

#include "mock/spi_mock.hpp"

#include "include/psql_utils/spi_session.hpp"
#include "include/psql_utils/postgres_includes.hpp"
#include "include/exceptions.hpp"

using namespace PsqlTools;
using ::testing::Return;
using ::testing::InSequence;

BOOST_AUTO_TEST_SUITE( spi_session )

BOOST_AUTO_TEST_CASE( positivie_session_create_and_destroy )
{
  auto spi_mock = SpiMock::create_and_get();
  {
    InSequence seq;
    EXPECT_CALL(*spi_mock, SPI_connect())
            .Times(1)
            .WillOnce(Return(SPI_OK_CONNECT));

    EXPECT_CALL(*spi_mock, SPI_finish())
            .Times(1)
            .WillOnce(Return(SPI_OK_CONNECT));
  }

  BOOST_CHECK_NO_THROW( PsqlTools::PsqlUtils::Spi::SpiSession::create() );
}

BOOST_AUTO_TEST_CASE( positivie_singleton_check )
{
  auto spi_mock = SpiMock::create_and_get();
  {
    InSequence seq;
    EXPECT_CALL(*spi_mock, SPI_connect())
      .Times(1)
      .WillOnce(Return(SPI_OK_CONNECT));

    EXPECT_CALL(*spi_mock, SPI_finish())
      .Times(1)
      .WillOnce(Return(SPI_OK_CONNECT));
  }

  auto session1 = PsqlTools::PsqlUtils::Spi::SpiSession::create();
  auto session2 = PsqlTools::PsqlUtils::Spi::SpiSession::create();
  BOOST_CHECK_EQUAL( session1, session2 );
}

BOOST_AUTO_TEST_CASE( negative_session_create )
{
  auto spi_mock = SpiMock::create_and_get();
  EXPECT_CALL(*spi_mock, SPI_connect())
          .Times(1)
          .WillOnce(Return(SPI_ERROR_CONNECT));

  BOOST_CHECK_THROW( PsqlTools::PsqlUtils::Spi::SpiSession::create(), ObjectInitializationException );
}

BOOST_AUTO_TEST_CASE( negative_session_close )
{
  auto spi_mock = SpiMock::create_and_get();
  EXPECT_CALL(*spi_mock, SPI_connect())
          .Times(1)
          .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL(*spi_mock, SPI_finish())
          .Times(1)
          .WillOnce(Return(SPI_ERROR_UNCONNECTED));

  BOOST_CHECK_NO_THROW( PsqlTools::PsqlUtils::Spi::SpiSession::create() ); // cannot throw from d_tor
}

BOOST_AUTO_TEST_SUITE_END()

