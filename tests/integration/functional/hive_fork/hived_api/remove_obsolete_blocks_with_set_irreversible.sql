DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:37-07'::timestamp, 1 )
         , ( 10, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 1 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 3 )
    ;

    INSERT INTO hive.transactions_reversible
    VALUES
           ( 4, 0::SMALLINT, '\xDEED40'::bytea, 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 5, 0::SMALLINT, '\xDEED55'::bytea, 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 6, 0::SMALLINT, '\xDEED60'::bytea, 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 10, 0::SMALLINT, '\xDEED11'::bytea, 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF'::bytea,  1 )
         , ( 7, 0::SMALLINT, '\xDEED70'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 8, 0::SMALLINT, '\xDEED80'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 9, 0::SMALLINT, '\xDEED90'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  2 )
         , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
         , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
    ;

    INSERT INTO hive.transactions_multisig_reversible
    VALUES
           ( '\xDEED40'::bytea, '\xBEEF40'::bytea,  1 )
         , ( '\xDEED55'::bytea, '\xBEEF55'::bytea,  1 )
         , ( '\xDEED60'::bytea, '\xBEEF61'::bytea,  1 ) --block 6
         , ( '\xDEED70'::bytea, '\xBEEF7110'::bytea,  1 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF7120'::bytea,  1 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF7130'::bytea,  1 ) -- block 7
         , ( '\xDEED11'::bytea, '\xBEEF7140'::bytea,  1 ) --must be abandon because of fork 2
         , ( '\xDEED70'::bytea, '\xBEEF72'::bytea,  2 ) -- block 7
         , ( '\xDEED70'::bytea, '\xBEEF73'::bytea,  2 ) -- block 7
         , ( '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ;

    INSERT INTO hive.operations_reversible
    VALUES
           ( 4, 4, 0, 0, 1, 'THREE OPERATION', 1 )
         , ( 5, 5, 0, 0, 1, 'FIVEFIVE OPERATION', 1 )
         , ( 6, 6, 0, 0, 1, 'SIX OPERATION', 1 )
         , ( 7, 7, 0, 0, 1, 'SEVEN0 OPERATION', 1 )
         , ( 8, 7, 0, 1, 1, 'SEVEN01 OPERATION', 1 )
         , ( 9, 7, 0, 2, 1, 'SEVEN02 OPERATION', 1 )
         , ( 7, 7, 0, 0, 1, 'SEVEN2 OPERATION', 2 )
         , ( 8, 7, 0, 1, 1, 'SEVEN21 OPERATION', 2 )
         , ( 9, 8, 0, 0, 1, 'EAIGHT2 OPERATION', 2 )
         , ( 10, 9, 0, 0, 1, 'NINE2 OPERATION', 2 )
         , ( 9, 8, 0, 0, 1, 'EIGHT3 OPERATION', 3 )
         , ( 10, 9, 0, 0, 1, 'NINE3 OPERATION', 3 )
         , ( 11, 10, 0, 0, 1, 'TEN OPERATION', 3 )
    ;

    UPDATE hive.app_context SET fork_id = 2, irreversible_block = 3, current_block_num = 8;
    -- SUMMARY:
    --We have 3 forks: 1 (blocks: 4,5,6),2 (blocks: 7,8,9) ,3 (blocks: 8,9, 10), moreover block 1,2,3,4 are
    --in set of irreversible blocks. There is one context which is working on 8 block on fork 2, and has information
    --that block nr 3 is last known irreversible block.

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
    -- block 8 from current top fork (nr 3 ) become irreversible
    PERFORM hive.remove_obsolete_reversible_data( 8 );
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT * FROM hive.blocks_reversible ), 'No reversible blocks';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.blocks_reversible
        EXCEPT SELECT * FROM ( VALUES
              ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:28-07'::timestamp, 2 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:29-07'::timestamp, 2 )
            , ( 8, '\xBADD80'::bytea, '\xCAFE80'::bytea, '2016-06-22 19:10:30-07'::timestamp, 3 )
            , ( 9, '\xBADD90'::bytea, '\xCAFE90'::bytea, '2016-06-22 19:10:31-07'::timestamp, 3 )
            , ( 10, '\xBADD1A'::bytea, '\xCAFE1A'::bytea, '2016-06-22 19:10:32-07'::timestamp, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.blocks_reversible';

    ASSERT EXISTS( SELECT * FROM hive.transactions_reversible ), 'No reversible transactions';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.transactions_reversible
        EXCEPT SELECT * FROM ( VALUES
               ( 8, 0::SMALLINT, '\xDEED80'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 9, 0::SMALLINT, '\xDEED90'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  2 )
             , ( 8, 0::SMALLINT, '\xDEED88'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 9, 0::SMALLINT, '\xDEED99'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea,  3 )
             , ( 10, 0::SMALLINT, '\xDEED1102'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea, 3 )
        ) as pattern
    ) , 'Unexpected rows in hive.transactions_reversible';

    ASSERT EXISTS( SELECT * FROM hive.transactions_multisig_reversible ), 'No reversible signatures';

    ASSERT NOT EXISTS (
    SELECT * FROM hive.transactions_multisig_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( '\xDEED80'::bytea, '\xBEEF82'::bytea,  2 ) -- block 8
         , ( '\xDEED90'::bytea, '\xBEEF92'::bytea,  2 ) -- block 9
         , ( '\xDEED88'::bytea, '\xBEEF83'::bytea,  3 ) -- block 8
         , ( '\xDEED99'::bytea, '\xBEEF93'::bytea,  3 ) -- block 9
         , ( '\xDEED1102'::bytea, '\xBEEF13'::bytea,  3 ) -- block 10
    ) as pattern
    ) , 'Unexpected rows in hive.transactions_multisig_reversible';


    ASSERT EXISTS( SELECT * FROM hive.operations_reversible ), 'No reversible oprations';

    ASSERT NOT EXISTS (
    SELECT * FROM hive.operations_reversible
    EXCEPT SELECT * FROM ( VALUES
           ( 9, 8, 0, 0, 1, 'EAIGHT2 OPERATION', 2 )
         , ( 10, 9, 0, 0, 1, 'NINE2 OPERATION', 2 )
         , ( 9, 8, 0, 0, 1, 'EIGHT3 OPERATION', 3 )
         , ( 10, 9, 0, 0, 1, 'NINE3 OPERATION', 3 )
         , ( 11, 10, 0, 0, 1, 'TEN OPERATION', 3 )
    ) as pattern
    ), 'Unexpected rows in hive.operations_reversible'
    ;
END;
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
