DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
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
DECLARE
    __first_block INT;
    __second_block INT;
    __third_block INT;
BEGIN
    SELECT hive.app_next_block( 'context' ) INTO __first_block;
    ASSERT __first_block = 1, 'Wrong first block';

    SELECT hive.app_next_block( 'context' ) INTO __second_block;
    ASSERT __second_block = 2, 'Wrong second block';

    SELECT hive.app_next_block( 'context' ) INTO __third_block;
    ASSERT __third_block IS NULL, 'Wrong second block';
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
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE id = 1 AND event = 'NEW_BLOCK' AND block_num = 2 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 1, 'Unexpected number of events';

    ASSERT ( SELECT current_block_num FROM hive.context WHERE name='context' ) = 2, 'Wrong current block num';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
