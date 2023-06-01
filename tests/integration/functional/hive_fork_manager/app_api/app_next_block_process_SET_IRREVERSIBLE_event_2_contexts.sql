DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
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

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    PERFORM hive.app_create_context( 'context2' );
    CREATE SCHEMA B;
    CREATE TABLE B.table2(id  INTEGER ) INHERITS( hive.context2 );

    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 1
    INSERT INTO A.table1(id) VALUES( 1 );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 2
    INSERT INTO A.table1(id) VALUES( 2 );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 3
    INSERT INTO A.table1(id) VALUES( 3 );

    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 1
    INSERT INTO B.table2(id) VALUES( 1 );
    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 2
    INSERT INTO B.table2(id) VALUES( 2 );
    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 3
    INSERT INTO B.table2(id) VALUES( 3 );

    PERFORM hive.set_irreversible( 3 );

    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
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
DECLARE
    __result INT;
BEGIN
    SELECT hive.app_next_block( 'context' ).first_block INTO __result;
    ASSERT __result IS NULL, 'Processing  SET_IRREVERSIBLE event did not return NULL';

    SELECT hive.app_next_block( 'context2' ) INTO __result;
    ASSERT __result IS NULL, 'Processing  SET_IRREVERSIBLE event by contex2 did not return NULL';
    PERFORM hive.app_next_block( 'context2' ); -- NEW_BLOCK event block 4
    INSERT INTO B.table2(id) VALUES( 4 );
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
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 3, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' ) = 4, 'Wrong events id';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context' ) = 3, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 3, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 3 ), 'No id 3';

    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Shadow table is not empty';

    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context2' ) = 4, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context2' ) = 5, 'Wrong events id';
    ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name='context2' ) = 3, 'Wrong irreversible';

    ASSERT ( SELECT COUNT(*)  FROM B.table2 ) = 4, 'Wrong number of rows in app table context2';
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 2 ), 'No id 2';
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 3 ), 'No id 3';
    ASSERT EXISTS ( SELECT *  FROM B.table2 WHERE id = 4 ), 'No id 4';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table2 ) = 1, 'Shadow table B.table2 is not empty';
END
$BODY$
;




