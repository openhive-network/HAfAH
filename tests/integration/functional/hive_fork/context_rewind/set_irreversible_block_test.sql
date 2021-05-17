DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 1 );
    CREATE TABLE table1( id INTEGER NOT NULL ) INHERITS( hive.base );
    PERFORM hive.context_next_block( 'context' ); -- 2
    INSERT INTO table1( id ) VALUES( 0 );
    PERFORM hive.context_next_block( 'context' ); -- 3
    INSERT INTO table1( id ) VALUES( 1 );
    PERFORM hive.context_next_block( 'context' ); -- 4
    INSERT INTO table1( id ) VALUES( 2 );
    PERFORM hive.context_next_block( 'context' ); -- 5
    INSERT INTO table1( id ) VALUES( 3 );

    PERFORM hive.context_create( 'context2', 1 );
    CREATE TABLE table2( id INTEGER NOT NULL ) INHERITS( hive.base );
    PERFORM hive.context_next_block( 'context2' ); -- 2
    INSERT INTO table2( id ) VALUES( 0 );
    PERFORM hive.context_next_block( 'context2' ); -- 3
    INSERT INTO table2( id ) VALUES( 1 );
    PERFORM hive.context_next_block( 'context2' ); -- 4
    INSERT INTO table2( id ) VALUES( 2 );
    PERFORM hive.context_next_block( 'context2' ); -- 5
    INSERT INTO table2( id ) VALUES( 3 );
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
    PERFORM hive.context_set_irreversible_block( 'context', 4 );
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
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 1, 'Wrong number of rows in the shadow table1';
    ASSERT EXISTS ( SELECT FROM hive.shadow_public_table1 hs WHERE hs.id = 3 AND hive_block_num = 5 ), 'No expected row';
    ASSERT EXISTS ( SELECT FROM hive.context hc WHERE hc.name = 'context' AND hc.irreversible_block = 4 ), 'Wrong irreversible block';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table2 ) = 4, 'Wrong number of rows in the shadow table2';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
