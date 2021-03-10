#pragma once

namespace ForkExtension::Spi {

    class SpiSession {
    public:
        SpiSession();
        ~SpiSession();

        void execute_read_select();
    };

} // namespace ForkExtension::Spi
