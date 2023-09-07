
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.back_from_fork( 2 );

    PERFORM hive.push_block(
         ( 3, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
    PERFORM hive.app_create_context( 'context2' );
    CREATE TABLE B.table2(id  INTEGER ) INHERITS( hive.context2 );

    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 1
    INSERT INTO A.table1(id) VALUES( 1 );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 2
    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 1
    INSERT INTO B.table2(id) VALUES( 11 );
    INSERT INTO A.table1(id) VALUES( 2 );

    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 2
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result INT;
BEGIN
    SELECT hive.app_next_block( 'context' ) INTO __result;
    ASSERT __result IS NULL, 'Processing  BFF event did not return NULL';

    PERFORM hive.app_next_block( 'context2' ); -- BFF EVENT event
    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 3
    INSERT INTO B.table2(id) VALUES( 14 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 2, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' ) = 4, 'Wrong events id';

    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context2' ) = 3, 'Wrong current block num context2';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context2' ) = 5, 'Wrong events id context2';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 2, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1' ;
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2' ;

    ASSERT ( SELECT COUNT(*)  FROM B.table2 ) = 2, 'Wrong number of rows in app table context2';
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 11 ), 'No id 11' ;
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 14 ), 'No id 14' ;
END
$BODY$
;




