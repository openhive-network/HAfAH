#include <boost/test/unit_test.hpp>

#include "include/postgres_includes.hpp"
#include "include/tuples_iterators.hpp"

struct TupleExample {
    uint16_t m_number_of_fields = htons( 5 );

    uint32_t m_field1_size = htonl( sizeof( uint32_t) );
    uint32_t m_field1_value = 0xABCDEFAB;
};

BOOST_AUTO_TEST_CASE( simple_iteration_by_fields )
{
  TupleExample tuple_pattern;
  bytea* tuple_bytes = reinterpret_cast< bytea* >( &tuple_pattern );
  ForkExtension::TuplesFieldIterator it( tuple_bytes );
}
