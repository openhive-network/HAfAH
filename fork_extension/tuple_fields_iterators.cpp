#include "include/tuple_fields_iterators.hpp"

#include "include/exceptions.hpp"

#include <cassert>

namespace ForkExtension {

TuplesFieldIterator::TuplesFieldIterator( bytea* _tuple_in_copy_format )
  : m_tuple_bytes( VARDATA( _tuple_in_copy_format ) )
  , m_tuple_size( VARSIZE( _tuple_in_copy_format ) -  VARHDRSZ ) {
    if ( m_tuple_bytes == nullptr ) {
      THROW_INITIALIZATION_ERROR( "Null tuple passed" );
    }

    if ( m_tuple_size < NUMBER_OF_FIELDS_SIZE ) {
      THROW_INITIALIZATION_ERROR( "Size of tuple is to small" );
    }

    m_number_of_fields = ntohs( *reinterpret_cast< uint16_t* >( VARDATA( m_tuple_bytes ) ) );
    m_current_field_number = 0;
    m_current_field = m_tuple_bytes + NUMBER_OF_FIELDS_SIZE;
}

TuplesFieldIterator::Field
TuplesFieldIterator::get_field() const {
  assert( !atEnd() && "Pass-end access");

  Field result;
  result.m_size = ntohl( *reinterpret_cast< uint32_t* >( m_current_field ) );
  result.m_value = m_current_field + FIELD_SIZE_SIZE;

  return result;
}

bool
TuplesFieldIterator::atEnd() const {
  return m_current_field_number == m_number_of_fields;
}

} // namespace ForkExtension

