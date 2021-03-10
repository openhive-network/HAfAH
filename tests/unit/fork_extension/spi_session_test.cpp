#include <boost/test/unit_test.hpp>

#include "mock/spi_mock.hpp"

#include "include/spi/spi_session.hpp"
#include "include/postgres_includes.hpp"
#include "include/exceptions.hpp"

using namespace ForkExtension;
using ::testing::Return;
using ::testing::InSequence;

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

  ForkExtension::Spi::SpiSession session_under_test;
}

BOOST_AUTO_TEST_CASE( negative_session_create )
{
  auto spi_mock = SpiMock::create_and_get();
  EXPECT_CALL(*spi_mock, SPI_connect())
          .Times(1)
          .WillOnce(Return(SPI_ERROR_CONNECT));

  BOOST_CHECK_THROW( { ForkExtension::Spi::SpiSession session; }, ObjectInitializationException );
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

  ForkExtension::Spi::SpiSession session;
}

