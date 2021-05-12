DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    PERFORM hive.context_next_block( 'context' ); -- block: 0
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive.context_next_block( 'context' ); -- block: 1
    UPDATE table1 SET id=321;
    PERFORM hive.context_next_block( 'context' ); -- block: 2
    UPDATE table1 SET id=231;
    PERFORM hive.context_next_block( 'context' ); -- block: 3
    UPDATE table1 SET id=132;
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
    PERFORM hive.back_context_from_fork( 'context' , 1 );
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=321 ) = 1, 'Updated row was not reverted or reverted to wrong number';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 2, 'Unexpected number of rows in the shadow table';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 WHERE hive_block_num = 0 ) = 1, 'No expected row (0) in the shadow table';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 WHERE hive_block_num = 1 ) = 1, 'No expected row (1) in the shadow table';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
