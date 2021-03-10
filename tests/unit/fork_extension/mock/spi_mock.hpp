#pragma once

#include <gmock/gmock.h>

class ISpiMock {
public:
    virtual ~ISpiMock() = default;

    virtual int SPI_connect() = 0;
    virtual int SPI_finish() = 0;
};

class SpiMock : public ISpiMock {
public:
    MOCK_METHOD( int, SPI_connect, () );
    MOCK_METHOD( int, SPI_finish, () );

    static std::shared_ptr<SpiMock> create_and_get();
};
