#include <boost/test/unit_test.hpp>

#include "include/postgres_includes.hpp"
#include "include/tuple_fields_iterators.hpp"
#include "include/to_bytea.hpp"

#include <cstring>
#include <memory>

struct TupleExample {
#pragma pack( push, 1)
  TupleExample(){
    m_number_of_fields = htons( 5 );
  }
    uint16_t m_number_of_fields;

    uint32_t m_field1_size = htonl( sizeof( uint32_t ) );
    uint32_t m_field1_value = 0xABCDEFAB;

    uint32_t m_field2_size = htonl( sizeof( float ) );
    float m_field2_value = 123.456;
};
#pragma pack( pop )


BOOST_AUTO_TEST_CASE( simple_iteration_by_fields )
{
  TupleExample tuple_pattern;
  auto tuple_bytea = ForkExtension::toBytea( &tuple_pattern );

  ForkExtension::TuplesFieldIterator it_under_test( tuple_bytea.get() );

  BOOST_REQUIRE( !it_under_test.atEnd() );

  auto field1 = it_under_test.get_field();
  BOOST_REQUIRE( field1.m_value );
  BOOST_REQUIRE_EQUAL( field1.m_size, ntohl( tuple_pattern.m_field1_size ) );
  BOOST_REQUIRE_EQUAL( *reinterpret_cast< uint32_t* >( field1.m_value ), tuple_pattern.m_field1_value );

//  auto field2 = it_under_test.get_field();
//  BOOST_REQUIRE( field2.m_value );
//  BOOST_REQUIRE_EQUAL( field2.m_size, ntohl( tuple_pattern.m_field2_size ) );
//  BOOST_REQUIRE_EQUAL( *reinterpret_cast< float* >( field1.m_value ), tuple_pattern.m_field2_value );
}
