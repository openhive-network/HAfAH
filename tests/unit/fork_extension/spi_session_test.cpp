#define BOOST_TEST_MODULE spi_session
#include <boost/test/unit_test.hpp>

#include "mock/spi_mock.hpp"

#include "include/spi/spi_session.hpp"
#include "include/postgres_includes.hpp"

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

