#include <boost/test/unit_test.hpp>

#include "include/relation_wrapper.hpp"

#include "mock/postgres_mock.hpp"

BOOST_AUTO_TEST_SUITE( relation )

BOOST_AUTO_TEST_CASE( get_pkey_columns ) {
  auto postgres_mock = PostgresMock::create_and_get();
  RelationData raw_relation;
  raw_relation.rd_id = 123;

  Bitmapset* columns_bitmap = reinterpret_cast< Bitmapset* >(0xAABBCCDDEEFFAABB);
  const ForkExtension::RelationWrapper::PrimaryKeyColumns expected_columns = {1, 3, 8 };
  static constexpr auto END_OF_BITMAP = -1;

  EXPECT_CALL( *postgres_mock, get_primary_key_attnos( raw_relation.rd_id, true, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( columns_bitmap ) );

  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, -1 ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[ 0 ] - FirstLowInvalidHeapAttributeNumber  ) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 0 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[1] - FirstLowInvalidHeapAttributeNumber ) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 1 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[2] - FirstLowInvalidHeapAttributeNumber) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 2 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( END_OF_BITMAP ) );


  ForkExtension::RelationWrapper relation_under_test(raw_relation );

  auto pk_columns = relation_under_test.getPrimaryKeysColumns();

  BOOST_REQUIRE_EQUAL( pk_columns.size(), 3 );
  BOOST_REQUIRE( pk_columns == expected_columns );
}

BOOST_AUTO_TEST_CASE( get_pkey_columns_no_pk ) {
  auto postgres_mock = PostgresMock::create_and_get();
  RelationData raw_relation;
  raw_relation.rd_id = 123;

  EXPECT_CALL( *postgres_mock, get_primary_key_attnos( raw_relation.rd_id, true, ::testing::_ ) )
          .Times( 1 )
          .WillOnce( ::testing::Return(  nullptr ) );

  ForkExtension::RelationWrapper relation_under_test(raw_relation );

  auto pk_columns = relation_under_test.getPrimaryKeysColumns();

  BOOST_REQUIRE( pk_columns.empty() );
}

BOOST_AUTO_TEST_SUITE_END()
