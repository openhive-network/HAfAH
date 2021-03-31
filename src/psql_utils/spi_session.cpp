#include "include/psql_utils/spi_session.hpp"

#include "include/psql_utils/postgres_includes.hpp"
#include "include/exceptions.hpp"

namespace {
  std::weak_ptr< PsqlTools::PsqlUtils::Spi::SpiSession > SPI_SESSION;
}

namespace PsqlTools::PsqlUtils::Spi {
  SpiSession::SpiSession() {
    if ( SPI_connect() != SPI_OK_CONNECT ) {
      THROW_INITIALIZATION_ERROR( "Cannot connect to SPI" );
    }
  }

  SpiSession::~SpiSession() {
    SPI_finish();
  }

  std::shared_ptr< SpiSession >
  SpiSession::create()
  {
    auto instance = SPI_SESSION.lock();
    if ( instance ) {
      return instance;
    }

    std::shared_ptr< SpiSession > new_session( new SpiSession() );
    SPI_SESSION = new_session;
    return new_session;
  }
} // namespace PsqlTools::PsqlUtils::Spi
