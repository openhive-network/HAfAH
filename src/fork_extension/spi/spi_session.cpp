#include "include/spi/spi_session.hpp"

#include "include/psql_utils/postgres_includes.hpp"
#include "include/exceptions.hpp"

namespace ForkExtension::Spi {
  SpiSession::SpiSession() {
    if ( SPI_connect() != SPI_OK_CONNECT ) {
      THROW_INITIALIZATION_ERROR( "Cannot connect to SPI" );
    }
  }

  SpiSession::~SpiSession() {
    SPI_finish();
  }
} // namespace ForkExtension::Spi
