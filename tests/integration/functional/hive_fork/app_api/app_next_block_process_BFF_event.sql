DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.back_from_fork( 2 );

    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.base );

    PERFORM hive.app_next_block( 'context' ); -- block 1
    INSERT INTO A.table1 VALUES( 1 );
    PERFORM hive.app_next_block( 'context' ); -- block 2
    INSERT INTO A.table1 VALUES( 2 );
    PERFORM hive.app_next_block( 'context' ); -- block 3
    INSERT INTO A.table1 VALUES( 3 );
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
    __result INT;
BEGIN
    SELECT hive.app_next_block( 'context' ) INTO __result;
    ASSERT __result IS NULL, 'Processing  BFF event did not return NULL';
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
    ASSERT ( SELECT current_block_num FROM hive.app_context WHERE name='context' ) = 2, 'Wrong current block num';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
