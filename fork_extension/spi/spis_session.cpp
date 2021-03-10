#include "include/spi/spis_session.hpp"

#include "include/postgres_includes.hpp"
#include "include/exceptions.hpp"

namespace ForkExtension::Spi {
  SpiSession::SpiSession() {
    if ( SPI_connect() != SPI_OK_CONNECT ) {
      THROW_RUNTIME_ERROR( "Cannot connect to SPI" );
    }
  }

  SpiSession::~SpiSession() {
    SPI_finish();
  }
} // namespace ForkExtension::Spi
