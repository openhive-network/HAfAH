DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
           ( 1, 'hive::protocol::pow_operation', FALSE )
         , ( 2, 'hive::protocol::pow2_operation', FALSE )
         , ( 3, 'hive::protocol::account_create_operation', FALSE )
         , ( 4, 'hive::protocol::create_claimed_account_operation', TRUE )
         , ( 5, 'hive::protocol::account_create_with_delegation_operation', FALSE )
         , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.operations
    VALUES
    ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{
       "worker_account":"account_from_pow",
       "block_id":"00000449f7860b82b4fbe2f317c670e9f01d6d9a",
       "nonce":3899,
       "work":{
          "worker":"STM7P5TDnA87Pj9T4mf6YHrhzjC1KbPZpNxLWCcVcHxNYXakpoT4F",
          "input":"ae8e7c677119d22385f8c48026fee7aad7bba693bf788d7f27047f40b47738c0",
          "signature":"1f38fe9a3f9989f84bd94aa5bbc88beaf09b67f825aa4450cf5105d111149ba6db560b582c7dbb026c7fc9c2eb5051815a72b17f6896ed59d3851d9a0f9883ca7a",
          "work":"000e7b209d58f2e64b36e9bf12b999c6c7af168cc3fc41eb7f8a4bf796c174c3"
       },
       "props":{
          "account_creation_fee":{
             "amount":"100000",
             "precision":3,
             "nai":"@@000000021"
          },
          "maximum_block_size":131072,
          "hbd_interest_rate":1000
       }
    }' ) --pow
         , ( 2, 2, 0, 0, 2, '2016-06-22 19:10:21-07'::timestamp, '{
        "work": [
          0,
          {
            "input": {
              "worker_account": "account_from_pow2",
              "prev_block": "003ea604345523c344fbadab605073ea712dd76f",
              "nonce": "1052853013628665497"
            },
            "pow_summary": 3817904373
          }
        ],
        "props": {
          "account_creation_fee": {
            "amount": "1",
            "precision": 3,
            "nai": "@@000000021"
          },
          "maximum_block_size": 131072,
          "hbd_interest_rate": 1000
        }
      }' ) --pow2
         , ( 3, 3, 0, 0, 3, '2016-06-22 19:10:21-07'::timestamp, '{"new_account_name": "account_from_create_account"}' )
         , ( 4, 4, 0, 0, 4, '2016-06-22 19:10:21-07'::timestamp, '{"new_account_name": "account_from_create_claimed_account"}' )
         , ( 5, 5, 0, 0, 5, '2016-06-22 19:10:21-07'::timestamp, '{"new_account_name": "account_from_create_claimed_account_del"}' )
         , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, 'other' )
    ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    --
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_providers_update( 1, 1, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 1, 'Wrong number of accounts 1';
    RETURN;
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow' ), 'account_from_pow not created';

    PERFORM hive.app_next_block( 'context' ); -- 2
    PERFORM hive.app_state_providers_update( 2, 2, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 2, 'Wrong number of accounts 2';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow2' ), 'account_from_pow2 not created';

    PERFORM hive.app_next_block( 'context' ); -- 3
    PERFORM hive.app_state_providers_update( 3, 3, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 3, 'Wrong number of accounts 3';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 4
    PERFORM hive.app_state_providers_update( 4, 4, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 4, 'Wrong number of accounts 4';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 5
    PERFORM hive.app_state_providers_update( 5, 5, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts 5';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    PERFORM hive.app_next_block( 'context' ); -- 6
    PERFORM hive.app_state_providers_update( 6, 6, 'context' );

    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;
