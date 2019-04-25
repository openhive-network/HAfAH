#include <boost/test/unit_test.hpp>

#include <steem/protocol/exceptions.hpp>
#include <steem/protocol/hardfork.hpp>
#include <steem/protocol/sps_operations.hpp>

#include <steem/chain/database.hpp>
#include <steem/chain/database_exceptions.hpp>
#include <steem/chain/steem_objects.hpp>

#include <steem/chain/util/reward.hpp>

#include <steem/plugins/rc/rc_objects.hpp>
#include <steem/plugins/rc/resource_count.hpp>

#include <steem/chain/sps_objects.hpp>

#include <fc/macros.hpp>
#include <fc/crypto/digest.hpp>

#include "../db_fixture/database_fixture.hpp"

#include <cmath>
#include <iostream>
#include <stdexcept>

using namespace steem;
using namespace steem::chain;
using namespace steem::protocol;
using fc::string;


BOOST_FIXTURE_TEST_SUITE( proposal_tests, sps_proposal_database_fixture )

BOOST_AUTO_TEST_CASE( generating_payments )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: generating payments" );

      ACTORS( (alice)(bob)(carol) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      //=====================preparing=====================
      auto creator = "alice";
      auto receiver = "bob";

      auto start_date = db->head_block_time();
      auto end_date = start_date + fc::days( 2 );

      auto daily_pay = asset( 48, SBD_SYMBOL );
      auto hourly_pay = asset( daily_pay.amount.value / 24, SBD_SYMBOL );

      FUND( creator, ASSET( "160.000 TESTS" ) );
      FUND( creator, ASSET( "80.000 TBD" ) );
      FUND( STEEM_TREASURY_ACCOUNT, ASSET( "5000.000 TBD" ) );

      auto voter_01 = "carol";
      //=====================preparing=====================

      //Needed basic operations
      int64_t id_proposal_00 = create_proposal( creator, receiver, start_date, end_date, daily_pay, alice_private_key );
      generate_blocks( 1 );

      vote_proposal( voter_01, { id_proposal_00 }, true/*approve*/, carol_private_key );
      generate_blocks( 1 );

      vest(STEEM_INIT_MINER_NAME, voter_01, ASSET( "1.000 TESTS" ));
      generate_blocks( 1 );

      //skipping interest generating is necessary
      transfer( STEEM_INIT_MINER_NAME, receiver, ASSET( "0.001 TBD" ));
      generate_block( 5 );
      transfer( STEEM_INIT_MINER_NAME, STEEM_TREASURY_ACCOUNT, ASSET( "0.001 TBD" ) );
      generate_block( 5 );

      const account_object& _creator = db->get_account( creator );
      const account_object& _receiver = db->get_account( receiver );
      const account_object& _voter_01 = db->get_account( voter_01 );
      const account_object& _treasury = db->get_account( STEEM_TREASURY_ACCOUNT );

      {
         BOOST_TEST_MESSAGE( "---Payment---" );

         auto before_creator_sbd_balance = _creator.sbd_balance;
         auto before_receiver_sbd_balance = _receiver.sbd_balance;
         auto before_voter_01_sbd_balance = _voter_01.sbd_balance;
         auto before_treasury_sbd_balance = _treasury.sbd_balance;
      
         auto next_block = get_nr_blocks_until_maintenance_block();
         generate_blocks( next_block - 1 );
         generate_blocks( 1 );

         auto after_creator_sbd_balance = _creator.sbd_balance;
         auto after_receiver_sbd_balance = _receiver.sbd_balance;
         auto after_voter_01_sbd_balance = _voter_01.sbd_balance;
         auto after_treasury_sbd_balance = _treasury.sbd_balance;
   
         BOOST_REQUIRE( before_creator_sbd_balance == after_creator_sbd_balance );
         BOOST_REQUIRE( before_receiver_sbd_balance == after_receiver_sbd_balance - hourly_pay );
         BOOST_REQUIRE( before_voter_01_sbd_balance == after_voter_01_sbd_balance );
         BOOST_REQUIRE( before_treasury_sbd_balance == after_treasury_sbd_balance + hourly_pay );
      }

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( proposals_maintenance)
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: removing inactive proposals" );
      //Update see issue #85 -> https://github.com/blocktradesdevs/steem/issues/85
      //Remove proposal will be automatic action - this test shall be temporary disabled.

      return ;

      ACTORS( (alice)(bob) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      //=====================preparing=====================
      auto creator = "alice";
      auto receiver = "bob";

      auto start_time = db->head_block_time();

      auto start_date_00 = start_time + fc::seconds( 30 );
      auto end_date_00 = start_time + fc::minutes( 10 );

      auto start_date_01 = start_time + fc::seconds( 40 );
      auto end_date_01 = start_time + fc::minutes( 30 );

      auto start_date_02 = start_time + fc::seconds( 50 );
      auto end_date_02 = start_time + fc::minutes( 20 );

      auto daily_pay = asset( 100, SBD_SYMBOL );

      FUND( creator, ASSET( "100.000 TBD" ) );
      //=====================preparing=====================

      int64_t id_proposal_00 = create_proposal( creator, receiver, start_date_00, end_date_00, daily_pay, alice_private_key );
      generate_block();

      int64_t id_proposal_01 = create_proposal( creator, receiver, start_date_01, end_date_01, daily_pay, alice_private_key );
      generate_block();

      int64_t id_proposal_02 = create_proposal( creator, receiver, start_date_02, end_date_02, daily_pay, alice_private_key );
      generate_block();

      {
         BOOST_REQUIRE( exist_proposal( id_proposal_00 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_01 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_02 ) );

         generate_blocks( start_time + fc::seconds( STEEM_PROPOSAL_MAINTENANCE_CLEANUP ) );
         start_time = db->head_block_time();

         BOOST_REQUIRE( exist_proposal( id_proposal_00 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_01 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_02 ) );

         generate_blocks( start_time + fc::minutes( 11 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_00 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_01 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_02 ) );

         generate_blocks( start_time + fc::minutes( 21 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_00 ) );
         BOOST_REQUIRE( exist_proposal( id_proposal_01 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_02 ) );

         generate_blocks( start_time + fc::minutes( 31 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_00 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_01 ) );
         BOOST_REQUIRE( !exist_proposal( id_proposal_02 ) );
      }

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}


BOOST_AUTO_TEST_CASE( proposal_object_apply )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create_proposal_operation" );

      ACTORS( (alice)(bob) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      auto fee = asset( STEEM_TREASURY_FEE, SBD_SYMBOL );

      auto creator = "alice";
      auto receiver = "bob";

      auto start_date = db->head_block_time() + fc::days( 1 );
      auto end_date = start_date + fc::days( 2 );

      auto daily_pay = asset( 100, SBD_SYMBOL );

      auto subject = "hello";
      auto permlink = "somethingpermlink";

      post_comment(creator, permlink, "title", "body", "test", alice_private_key);

      FUND( creator, ASSET( "80.000 TBD" ) );

      signed_transaction tx;

      const account_object& before_treasury_account = db->get_account(STEEM_TREASURY_ACCOUNT);
      const account_object& before_alice_account = db->get_account( creator );
      const account_object& before_bob_account = db->get_account( receiver );

      auto before_alice_sbd_balance = before_alice_account.sbd_balance;
      auto before_bob_sbd_balance = before_bob_account.sbd_balance;
      auto before_treasury_balance = before_treasury_account.sbd_balance;

      create_proposal_operation op;

      op.creator = creator;
      op.receiver = receiver;

      op.start_date = start_date;
      op.end_date = end_date;

      op.daily_pay = daily_pay;

      op.subject = subject;
      op.permlink = permlink;

      tx.operations.push_back( op );
      tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
      sign( tx, alice_private_key );
      db->push_transaction( tx, 0 );
      tx.operations.clear();
      tx.signatures.clear();

      const auto& after_treasury_account = db->get_account(STEEM_TREASURY_ACCOUNT);
      const account_object& after_alice_account = db->get_account( creator );
      const account_object& after_bob_account = db->get_account( receiver );

      auto after_alice_sbd_balance = after_alice_account.sbd_balance;
      auto after_bob_sbd_balance = after_bob_account.sbd_balance;
      auto after_treasury_balance = after_treasury_account.sbd_balance;

      BOOST_REQUIRE( before_alice_sbd_balance == after_alice_sbd_balance + fee );
      BOOST_REQUIRE( before_bob_sbd_balance == after_bob_sbd_balance );
      /// Fee shall be paid to treasury account.
      BOOST_REQUIRE(before_treasury_balance == after_treasury_balance - fee);

      const auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( creator );
      BOOST_REQUIRE( found != proposal_idx.end() );

      BOOST_REQUIRE( found->creator == creator );
      BOOST_REQUIRE( found->receiver == receiver );
      BOOST_REQUIRE( found->start_date == start_date );
      BOOST_REQUIRE( found->end_date == end_date );
      BOOST_REQUIRE( found->daily_pay == daily_pay );
      BOOST_REQUIRE( found->subject == subject );
      BOOST_REQUIRE( found->permlink == permlink );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( proposal_vote_object_apply )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: proposal_vote_object_operation" );

      ACTORS( (alice)(bob)(carol)(dan) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      auto creator = "alice";
      auto receiver = "bob";

      auto start_date = db->head_block_time() + fc::days( 1 );
      auto end_date = start_date + fc::days( 2 );

      auto daily_pay = asset( 100, SBD_SYMBOL );

      FUND( creator, ASSET( "80.000 TBD" ) );

      int64_t id_proposal_00 = create_proposal( creator, receiver, start_date, end_date, daily_pay, alice_private_key );

      signed_transaction tx;
      update_proposal_votes_operation op;
      const auto& proposal_vote_idx = db->get_index< proposal_vote_index >().indices().get< by_voter_proposal >();

      auto voter_01 = "carol";
      auto voter_01_key = carol_private_key;

      {
         BOOST_TEST_MESSAGE( "---Voting for proposal( `id_proposal_00` )---" );
         op.voter = voter_01;
         op.proposal_ids.insert( id_proposal_00 );
         op.approve = true;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         auto found = proposal_vote_idx.find( std::make_tuple( voter_01, id_proposal_00 ) );
         BOOST_REQUIRE( found->voter == voter_01 );
         BOOST_REQUIRE( static_cast< int64_t >( found->proposal_id ) == id_proposal_00 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting proposal( `id_proposal_00` )---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_00 );
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         auto found = proposal_vote_idx.find( std::make_tuple( voter_01, id_proposal_00 ) );
         BOOST_REQUIRE( found == proposal_vote_idx.end() );
      }

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( proposal_vote_object_01_apply )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: proposal_vote_object_operation" );

      ACTORS( (alice)(bob)(carol)(dan) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      auto creator = "alice";
      auto receiver = "bob";

      auto start_date = db->head_block_time() + fc::days( 1 );
      auto end_date = start_date + fc::days( 2 );

      auto daily_pay_00 = asset( 100, SBD_SYMBOL );
      auto daily_pay_01 = asset( 101, SBD_SYMBOL );
      auto daily_pay_02 = asset( 102, SBD_SYMBOL );

      FUND( creator, ASSET( "80.000 TBD" ) );

      int64_t id_proposal_00 = create_proposal( creator, receiver, start_date, end_date, daily_pay_00, alice_private_key );
      int64_t id_proposal_01 = create_proposal( creator, receiver, start_date, end_date, daily_pay_01, alice_private_key );

      signed_transaction tx;
      update_proposal_votes_operation op;
      const auto& proposal_vote_idx = db->get_index< proposal_vote_index >().indices().get< by_voter_proposal >();

      std::string voter_01 = "carol";
      auto voter_01_key = carol_private_key;

      {
         BOOST_TEST_MESSAGE( "---Voting by `voter_01` for proposals( `id_proposal_00`, `id_proposal_01` )---" );
         op.voter = voter_01;
         op.proposal_ids.insert( id_proposal_00 );
         op.proposal_ids.insert( id_proposal_01 );
         op.approve = true;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 2 );
      }

      int64_t id_proposal_02 = create_proposal( creator, receiver, start_date, end_date, daily_pay_02, alice_private_key );
      std::string voter_02 = "dan";
      auto voter_02_key = dan_private_key;

      {
         BOOST_TEST_MESSAGE( "---Voting by `voter_02` for proposals( `id_proposal_00`, `id_proposal_01`, `id_proposal_02` )---" );
         op.voter = voter_02;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_02 );
         op.proposal_ids.insert( id_proposal_00 );
         op.proposal_ids.insert( id_proposal_01 );
         op.approve = true;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_02_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_02 );
         while( found != proposal_vote_idx.end() && found->voter == voter_02 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 3 );
      }

      {
         BOOST_TEST_MESSAGE( "---Voting by `voter_02` for proposals( `id_proposal_00` )---" );
         op.voter = voter_02;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_00 );
         op.approve = true;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_02_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_02 );
         while( found != proposal_vote_idx.end() && found->voter == voter_02 )
         {
            ++cnt;
            ++found;
         }
        BOOST_REQUIRE( cnt == 3 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting by `voter_01` proposals( `id_proposal_02` )---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_02 );
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 2 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting by `voter_01` proposals( `id_proposal_00` )---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_00 );
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 1 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting by `voter_02` proposals( `id_proposal_00`, `id_proposal_01`, `id_proposal_02` )---" );
         op.voter = voter_02;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_02 );
         op.proposal_ids.insert( id_proposal_01 );
         op.proposal_ids.insert( id_proposal_00 );
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_02_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_02 );
         while( found != proposal_vote_idx.end() && found->voter == voter_02 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 0 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting by `voter_01` proposals( `id_proposal_01` )---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.proposal_ids.insert( id_proposal_01 );
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 0 );
      }

      {
         BOOST_TEST_MESSAGE( "---Voting by `voter_01` for nothing---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.approve = true;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 0 );
      }

      {
         BOOST_TEST_MESSAGE( "---Unvoting by `voter_01` nothing---" );
         op.voter = voter_01;
         op.proposal_ids.clear();
         op.approve = false;

         tx.operations.push_back( op );
         tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
         sign( tx, voter_01_key );
         db->push_transaction( tx, 0 );
         tx.operations.clear();
         tx.signatures.clear();

         int32_t cnt = 0;
         auto found = proposal_vote_idx.find( voter_01 );
         while( found != proposal_vote_idx.end() && found->voter == voter_01 )
         {
            ++cnt;
            ++found;
         }
         BOOST_REQUIRE( cnt == 0 );
      }

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}


struct create_proposal_data {
      std::string creator    ;
      std::string receiver   ;
      fc::time_point_sec start_date ;
      fc::time_point_sec end_date   ;
      steem::protocol::asset daily_pay ;
      std::string subject ;   
      std::string url     ;   

      create_proposal_data(fc::time_point_sec _start) {
         creator    = "alice";
         receiver   = "bob";
         start_date = _start     + fc::days( 1 );
         end_date   = start_date + fc::days( 2 );
         daily_pay  = asset( 100, SBD_SYMBOL );
         subject    = "hello";
         url        = "http:://something.html";
      }
};

BOOST_AUTO_TEST_CASE( create_proposal_000 )
{
   try {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - all args are ok" );
      ACTORS( (alice)(bob) )
      generate_block();

      set_price_feed( price( ASSET( "1.000 TBD" ), ASSET( "1.000 TESTS" ) ) );
      generate_block();

      auto creator    = "alice";
      auto receiver   = "bob";
      auto start_date = db->head_block_time() + fc::days( 1 );
      auto end_date   = start_date + fc::days( 2 );
      auto daily_pay  = asset( 100, SBD_SYMBOL );

      FUND( creator, ASSET( "80.000 TBD" ) );
      {
         int64_t proposal = create_proposal( creator, receiver, start_date, end_date, daily_pay, alice_private_key );
         BOOST_REQUIRE( proposal >= 0 );
      }
      validate_database();
   } FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_001 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid creator" );
      {
         create_proposal_data cpd(db->head_block_time());
         ACTORS( (alice)(bob) )
         generate_block();
         FUND( cpd.creator, ASSET( "80.000 TBD" ) );
         STEEM_REQUIRE_THROW( create_proposal( "", cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ), fc::exception);
         
      }
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_002 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid receiver" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      STEEM_REQUIRE_THROW(create_proposal( cpd.creator, "", cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ), fc::exception);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_003 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid start date" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      cpd.start_date = cpd.end_date + fc::days(2);
      STEEM_REQUIRE_THROW(create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ), fc::exception);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_004 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid end date" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      cpd.end_date = cpd.start_date - fc::days(2);
      STEEM_REQUIRE_THROW(create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ), fc::exception);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_005 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid subject(empty)" );
      ACTORS( (alice)(bob) )
      generate_block();
      create_proposal_operation cpo;
      cpo.creator    = "alice";
      cpo.receiver   = "bob";
      cpo.start_date = db->head_block_time() + fc::days( 1 );
      cpo.end_date   = cpo.start_date + fc::days( 2 );
      cpo.daily_pay  = asset( 100, SBD_SYMBOL );
      cpo.subject    = "";
      cpo.permlink        = "http:://something.html";
      FUND( cpo.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      signed_transaction tx;
      tx.operations.push_back( cpo );
      tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
      sign( tx, alice_private_key );
      STEEM_REQUIRE_THROW(db->push_transaction( tx, 0 ), fc::exception);
      tx.operations.clear();
      tx.signatures.clear();
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_006 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid subject(too long)" );
      ACTORS( (alice)(bob) )
      generate_block();
      create_proposal_operation cpo;
      cpo.creator    = "alice";
      cpo.receiver   = "bob";
      cpo.start_date = db->head_block_time() + fc::days( 1 );
      cpo.end_date   = cpo.start_date + fc::days( 2 );
      cpo.daily_pay  = asset( 100, SBD_SYMBOL );
      cpo.subject    = "very very very very very very long long long long long long subject subject subject subject subject subject";
      cpo.permlink        = "http:://something.html";
      FUND( cpo.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      signed_transaction tx;
      tx.operations.push_back( cpo );
      tx.set_expiration( db->head_block_time() + STEEM_MAX_TIME_UNTIL_EXPIRATION );
      sign( tx, alice_private_key );
      STEEM_REQUIRE_THROW(db->push_transaction( tx, 0 ), fc::exception);
      tx.operations.clear();
      tx.signatures.clear();
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_007 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: authorization test" );
      ACTORS( (alice)(bob) )
      generate_block();
      create_proposal_operation cpo;
      cpo.creator    = "alice";
      cpo.receiver   = "bob";
      cpo.start_date = db->head_block_time() + fc::days( 1 );
      cpo.end_date   = cpo.start_date + fc::days( 2 );
      cpo.daily_pay  = asset( 100, SBD_SYMBOL );
      cpo.subject    = "subject";
      cpo.permlink        = "http:://something.html";

      flat_set< account_name_type > auths;
      flat_set< account_name_type > expected;

      cpo.get_required_owner_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      cpo.get_required_posting_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      expected.insert( "alice" );
      cpo.get_required_active_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( create_proposal_008 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: create proposal: opration arguments validation - invalid daily payement (negative value)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      generate_block();
      cpd.end_date = cpd.start_date + fc::days(20);
      cpd.daily_pay = asset( -10, SBD_SYMBOL );
      STEEM_REQUIRE_THROW(create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ), fc::exception);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_000 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - all ok (approve true)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      std::vector< int64_t > proposals = {proposal_1};
      vote_proposal("carol", proposals, true, carol_private_key);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_001 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - all ok (approve false)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      std::vector< int64_t > proposals = {proposal_1};
      vote_proposal("carol", proposals, false, carol_private_key);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_002 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - all ok (empty array)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      std::vector< int64_t > proposals;
      vote_proposal("carol", proposals, true, carol_private_key);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_003 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - all ok (array with negative digits)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      std::vector< int64_t > proposals = {-1, -2, -3, -4, -5};
      vote_proposal("carol", proposals, true, carol_private_key);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_004 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - invalid voter" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      std::vector< int64_t > proposals = {proposal_1};
      STEEM_REQUIRE_THROW(vote_proposal("urp", proposals, false, carol_private_key), fc::exception);
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_005 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: opration arguments validation - invalid id array (array with greater number of digits than allowed)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      std::vector< int64_t > proposals;
      for(int i = 0; i <= STEEM_PROPOSAL_MAX_IDS_NUMBER; i++) {
         proposals.push_back(i);
      }
      STEEM_REQUIRE_THROW(vote_proposal("carol", proposals, true, carol_private_key), fc::exception);
      
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( update_proposal_votes_006 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: update proposal votes: authorization test" );
      ACTORS( (alice)(bob) )
      generate_block();
      update_proposal_votes_operation upv;
      upv.voter = "alice";
      upv.proposal_ids = {0};
      upv.approve = true;

      flat_set< account_name_type > auths;
      flat_set< account_name_type > expected;

      upv.get_required_owner_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      upv.get_required_posting_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      expected.insert( "alice" );
      upv.get_required_active_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_000 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proposal removal (only one)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 1 );

      flat_set<int64_t> proposals = { proposal_1 };
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_001 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proposal removal (one from many)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();


      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      int64_t proposal_2 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      int64_t proposal_3 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      BOOST_REQUIRE(proposal_2 >= 0);
      BOOST_REQUIRE(proposal_3 >= 0);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 3 );

      flat_set<int64_t> proposals = { proposal_1 };
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );   //two left
      BOOST_REQUIRE( proposal_idx.size() == 2 );

      proposals.clear();
      proposals.insert(proposal_2);
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );   //one left
      BOOST_REQUIRE( proposal_idx.size() == 1 );

      proposals.clear();
      proposals.insert(proposal_3);
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );   //none
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_002 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proposal removal (n from many in two steps)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal = -1;
      std::vector<int64_t> proposals;

      for(int i = 0; i < 6; i++) {
         proposal = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
         BOOST_REQUIRE(proposal >= 0);
         proposals.push_back(proposal);
      }
      BOOST_REQUIRE(proposals.size() == 6);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE(proposal_idx.size() == 6);

      flat_set<int64_t> proposals_to_erase = {proposals[0], proposals[1], proposals[2], proposals[3]};
      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 2 );

      proposals_to_erase.clear();
      proposals_to_erase.insert(proposals[4]);
      proposals_to_erase.insert(proposals[5]);

      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);
      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_003 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proper proposal deletion check (one at time)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal = -1;
      std::vector<int64_t> proposals;

      for(int i = 0; i < 2; i++) {
         proposal = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
         BOOST_REQUIRE(proposal >= 0);
         proposals.push_back(proposal);
      }
      BOOST_REQUIRE(proposals.size() == 2);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE(proposal_idx.size() == 2);

      flat_set<int64_t> proposals_to_erase = {proposals[0]};
      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( int64_t(found->id)  == proposals[1]);
      BOOST_REQUIRE( proposal_idx.size() == 1 );

      proposals_to_erase.clear();
      proposals_to_erase.insert(proposals[1]);

      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);
      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_004 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proper proposal deletion check (two at one time)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal = -1;
      std::vector<int64_t> proposals;

      for(int i = 0; i < 6; i++) {
         proposal = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
         BOOST_REQUIRE(proposal >= 0);
         proposals.push_back(proposal);
      }
      BOOST_REQUIRE(proposals.size() == 6);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE(proposal_idx.size() == 6);

      flat_set<int64_t> proposals_to_erase = {proposals[0], proposals[5]};
      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      for(auto& it : proposal_idx) {
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[0] );
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[5] );
      }
      BOOST_REQUIRE( proposal_idx.size() == 4 );

      proposals_to_erase.clear();
      proposals_to_erase.insert(proposals[1]);
      proposals_to_erase.insert(proposals[4]);

      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);
      found = proposal_idx.find( cpd.creator );
      for(auto& it : proposal_idx) {
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[0] );
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[1] );
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[4] );
         BOOST_REQUIRE( static_cast< int64_t >(it.id) != proposals[5] );
      }
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 2 );

      proposals_to_erase.clear();
      proposals_to_erase.insert(proposals[2]);
      proposals_to_erase.insert(proposals[3]);
      remove_proposal(cpd.creator, proposals_to_erase, alice_private_key);
      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_005 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - proposal with votes removal (only one)." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);

      auto& proposal_idx      = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found       = proposal_idx.find( cpd.creator );
      
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 1 );

      std::vector<int64_t> vote_proposals = {proposal_1};

      vote_proposal( "bob", vote_proposals, true, bob_private_key );
      BOOST_REQUIRE( find_vote_for_proposal("bob", proposal_1) );

      flat_set<int64_t> proposals = { proposal_1 };
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_006 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - remove proposal with votes and one voteless at same time." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      int64_t proposal_2 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      BOOST_REQUIRE(proposal_2 >= 0);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 2 );

      std::vector<int64_t> vote_proposals = {proposal_1};

      vote_proposal( "bob",   vote_proposals, true, bob_private_key );
      BOOST_REQUIRE( find_vote_for_proposal("bob", proposal_1) );

      flat_set<int64_t> proposals = { proposal_1, proposal_2 };
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_007 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: basic verification operation - remove proposals with votes at same time." );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      int64_t proposal_2 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      BOOST_REQUIRE(proposal_2 >= 0);

      auto& proposal_idx = db->get_index< proposal_index >().indices().get< by_creator >();
      auto found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found != proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.size() == 2 );

      std::vector<int64_t> vote_proposals = {proposal_1};
      vote_proposal( "bob",   vote_proposals, true, bob_private_key );
      BOOST_REQUIRE( find_vote_for_proposal("bob", proposal_1) );
      vote_proposals.clear();
      vote_proposals.push_back(proposal_2);
      vote_proposal( "carol", vote_proposals, true, carol_private_key );
      BOOST_REQUIRE( find_vote_for_proposal("carol", proposal_2) );

      flat_set<int64_t> proposals = { proposal_1, proposal_2 };
      remove_proposal(cpd.creator, proposals, alice_private_key);

      found = proposal_idx.find( cpd.creator );
      BOOST_REQUIRE( found == proposal_idx.end() );
      BOOST_REQUIRE( proposal_idx.empty() );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_008 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: opration arguments validation - all ok" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      flat_set<int64_t> proposals = { 0 };
      remove_proposal(cpd.creator, proposals, alice_private_key); 
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_009 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: opration arguments validation - invalid deleter" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      flat_set<int64_t> proposals = { proposal_1 };
      STEEM_REQUIRE_THROW(remove_proposal(cpd.receiver, proposals, bob_private_key), fc::exception); 
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_010 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: opration arguments validation - invalid array(empty array)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      flat_set<int64_t> proposals;
      STEEM_REQUIRE_THROW(remove_proposal(cpd.creator, proposals, bob_private_key), fc::exception); 
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_011 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: opration arguments validation - invalid array(array with greater number of digits than allowed)" );
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();
      flat_set<int64_t> proposals;
      for(int i = 0; i <= STEEM_PROPOSAL_MAX_IDS_NUMBER; i++) {
         proposals.insert(create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key ));
      }
      STEEM_REQUIRE_THROW(remove_proposal(cpd.creator, proposals, bob_private_key), fc::exception); 
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( remove_proposal_012 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: remove proposal: authorization test" );
      ACTORS( (alice)(bob) )
      generate_block();
      remove_proposal_operation rpo;
      rpo.proposal_owner = "alice";
      rpo.proposal_ids = {1,2,3};

      flat_set< account_name_type > auths;
      flat_set< account_name_type > expected;

      rpo.get_required_owner_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      rpo.get_required_posting_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      expected.insert( "alice" );
      rpo.get_required_active_authorities( auths );
      BOOST_REQUIRE( auths == expected );

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( list_proposal_000 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: list proposals: arguments validation check - all ok" );
      plugin_prepare();

      std::vector<std::string> order_by        {"creator", "start_date", "end_date", "total_votes"};
      for(auto by : order_by) {
         auto order_by        = steem::plugins::sps::to_order_by(by);
         if( by == "creator") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_creator );
         } else if ( by == "start_date") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_start_date );
         } else if ( by == "end_date") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_end_date );
         } else if ( by == "total_votes"){
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_total_votes );
         } else {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_creator );
         }
      }

      std::vector<std::string> order_direction {"asc", "desc"};
      for(auto direct : order_direction) {
         auto order_direction = steem::plugins::sps::to_order_direction(direct);
         if( direct == "asc") {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_ascending );
         } else if ( direct == "desc") {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_descending );
         } else {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_ascending );
         }
      }

      std::vector<std::string> active          {"active", "inactive", "all"};
      for(auto act : active){
         auto status          = steem::plugins::sps::to_proposal_status(act);
         if( act == "active") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::active );
         } else if ( act == "inactive") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::inactive );
         } else if ( act == "all") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::all );
         } else {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::all );
         }
      }
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( list_proposal_001 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: list proposals: call result check - all ok" );
      plugin_prepare();
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      auto checker = [this, cpd](bool _empty){
         std::vector<std::string> active          {"active", "inactive", "all"};
         std::vector<std::string> order_by        {"creator", "start_date", "end_date", "total_votes"};
         std::vector<std::string> order_direction {"asc", "desc"};
         fc::variant start = 0;
         for(auto by : order_by) {
            if (by == "creator"){
               start = "";
            } else if (by == "start_date" || by == "end_date") {
               start = "2016-03-01T00:00:00";
            } else {
               start = 0;
            }
            for(auto direct : order_direction) {
               for(auto act : active) {
                  auto resp = list_proposals(start, by, direct,1, act, "");
                  if(_empty) {
                     BOOST_REQUIRE(resp.empty());
                  } else {
                     BOOST_REQUIRE(!resp.empty());
                  }
               }
            }
         }
      };

      checker(true);
      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);
      auto resp = list_proposals(cpd.creator, "creator", "asc", 10, "all", "");
      BOOST_REQUIRE(!resp.empty());
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( list_voter_proposals_000 )
{
   try
   {
      plugin_prepare();

      std::vector<std::string> order_by        {"creator", "start_date", "end_date", "total_votes"};
      for(auto by : order_by) {
         auto order_by        = steem::plugins::sps::to_order_by(by);
         if( by == "creator") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_creator );
         } else if ( by == "start_date") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_start_date );
         } else if ( by == "end_date") {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_end_date );
         } else if ( by == "total_votes"){
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_total_votes );
         } else {
            BOOST_REQUIRE( order_by == steem::plugins::sps::order_by_type::by_creator );
         }
      }

      std::vector<std::string> order_direction {"asc", "desc"};
      for(auto direct : order_direction) {
         auto order_direction = steem::plugins::sps::to_order_direction(direct);
         if( direct == "asc") {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_ascending );
         } else if ( direct == "desc") {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_descending );
         } else {
            BOOST_REQUIRE( order_direction == steem::plugins::sps::order_direction_type::direction_ascending );
         }
      }

      std::vector<std::string> active          {"active", "inactive", "all"};
      for(auto act : active){
         auto status          = steem::plugins::sps::to_proposal_status(act);
         if( act == "active") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::active );
         } else if ( act == "inactive") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::inactive );
         } else if ( act == "all") {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::all );
         } else {
            BOOST_REQUIRE( status == steem::plugins::sps::proposal_status::all );
         }
      }
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( list_voter_proposals_001 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: list voter proposals: call result check - all ok" );
      plugin_prepare();
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      auto checker = [this, cpd](bool _empty){
         std::vector<std::string> active          {"active", "inactive", "all"};
         std::vector<std::string> order_by        {"creator", "start_date", "end_date", "total_votes"};
         std::vector<std::string> order_direction {"asc", "desc"};
         for(auto by : order_by) {
            for(auto direct : order_direction) {
               for(auto act : active) {
                  auto resp = list_voter_proposals(cpd.creator, by, direct,10, act);
                  if(_empty) {
                     BOOST_REQUIRE(resp.empty());
                  } else {
                     BOOST_REQUIRE(!resp.empty());
                  }
               }
            }
         }
      };

      checker(true);
      int64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      checker(true);
      BOOST_REQUIRE(proposal_1 >= 0);
      std::vector< int64_t > proposals = {proposal_1};
      vote_proposal(cpd.creator, proposals, true, alice_private_key);
      auto resp = list_voter_proposals(cpd.creator, "creator", "asc", 10, "all");
      BOOST_REQUIRE(!resp.empty());
      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_CASE( find_proposals_000 )
{
   try
   {
      BOOST_TEST_MESSAGE( "Testing: find proposals: call result check - all ok" );
      plugin_prepare();
      create_proposal_data cpd(db->head_block_time());
      ACTORS( (alice)(bob)(carol) )
      generate_block();
      FUND( cpd.creator, ASSET( "80.000 TBD" ) );
      generate_block();

      flat_set<uint64_t> prop_before = {0};
      auto resp = find_proposals(prop_before);
      BOOST_REQUIRE(resp.empty());

      uint64_t proposal_1 = create_proposal( cpd.creator, cpd.receiver, cpd.start_date, cpd.end_date, cpd.daily_pay, alice_private_key );
      BOOST_REQUIRE(proposal_1 >= 0);

      flat_set<uint64_t> prop_after = {proposal_1};
      resp = find_proposals(prop_after);
      BOOST_REQUIRE(!resp.empty());

      validate_database();
   }
   FC_LOG_AND_RETHROW()
}

BOOST_AUTO_TEST_SUITE_END()
