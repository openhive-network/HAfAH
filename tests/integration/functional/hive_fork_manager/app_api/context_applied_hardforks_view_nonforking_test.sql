DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;


    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    INSERT INTO hive.operations
    VALUES
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' )
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' )
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
           ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}', 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"FIVEFIVE OPERATION"}}', 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}', 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN0 OPERATION"}}', 1 ) -- must be abandon because of fork2
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN01 OPERATION"}}', 1 ) -- must be abandon because of fork2
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN02 OPERATION"}}', 1 ) -- must be abandon because of fork2
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}', 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}', 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EAIGHT2 OPERATION"}}', 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}', 2 )
         , ( 8, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}', 3 )
         , ( 9, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}', 3 )
         , ( 10, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}', 3 )
;

INSERT INTO hive.applied_hardforks
VALUES
       ( 1, 1, 1 )
     , ( 2, 2, 2 )
     , ( 3, 3, 3 )
     , ( 4, 4, 4 )
;

INSERT INTO hive.applied_hardforks_reversible
VALUES
       ( 4, 4, 4, 1 )
     , ( 5, 5, 5, 1 )
     , ( 6, 6, 6, 1 )
     , ( 7, 7, 7, 1 ) -- must be abandon because of fork2
     , ( 8, 7, 8, 1 ) -- must be abandon because of fork2
     , ( 9, 7, 9, 1 ) -- must be abandon because of fork2
     , ( 7, 7, 7, 2 )
     , ( 8, 7, 8, 2 )
     , ( 9, 8, 9, 2 )
     , ( 10, 9, 10, 2 )
     , ( 8, 8, 8, 3 )
     , ( 9, 9, 9, 3 )
     , ( 10, 10, 10, 3 )
;


    UPDATE hive.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
END;
$BODY$
;


DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    --NOTHING TODO HERE
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_applied_hardforks_view' ), 'No context applied_hardfroks view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_applied_hardforks_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 1, 1 )
            , ( 2, 2, 2 )
            , ( 3, 3, 3 )
            , ( 4, 4, 4 )
        ) as pattern
    ) , 'Unexpected rows in the view';


    ASSERT ( SELECT COUNT(*) FROM hive.context_applied_hardforks_view ) = 4, 'Not all rows are visible';
    
END;
$BODY$
;