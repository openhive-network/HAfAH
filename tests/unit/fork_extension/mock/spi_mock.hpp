#pragma once

#include <gmock/gmock.h>

#include "include/postgres_includes.hpp"

class ISpiMock {
public:
    virtual ~ISpiMock() = default;

    virtual int SPI_connect() = 0;
    virtual int SPI_finish() = 0;
    virtual Datum SPI_getbinval(HeapTuple, TupleDesc, int, bool*) = 0;
};

class SpiMock : public ISpiMock {
public:
    MOCK_METHOD( int, SPI_connect, () );
    MOCK_METHOD( int, SPI_finish, () );
    MOCK_METHOD( Datum, SPI_getbinval, (HeapTuple, TupleDesc, int, bool*) );

    static std::shared_ptr<SpiMock> create_and_get();
};
