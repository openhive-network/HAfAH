#pragma once

#include <memory>

namespace PsqlTools::PsqlUtils::Spi {

  class SpiSession {
    public:
      ~SpiSession();

      static std::shared_ptr< SpiSession > create();
  private:
    SpiSession();
  };

} // namespace PsqlTools::PsqlUtilsSpi
