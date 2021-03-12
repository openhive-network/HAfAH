#pragma once

#include "include/postgres_includes.hpp"

#include <memory>

namespace ForkExtension {

    template< typename _Data >
    std::unique_ptr< bytea > toBytea( _Data* _data ) {
      std::unique_ptr< bytea > result( ( bytea* )new uint8_t[ sizeof( _Data ) + VARHDRSZ ] );
      std::memcpy( VARDATA( result.get() ), _data, sizeof( _Data ) );
      SET_VARSIZE( result.get(), sizeof( _Data ) + VARHDRSZ );

      return result;
    }
} //namespace ForkExtension
