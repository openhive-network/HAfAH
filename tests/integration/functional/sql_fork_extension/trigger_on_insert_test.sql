DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );
    CREATE TABLE hive.table1( id INTEGER NOT NULL, smth TEXT NOT NULL );
    PERFORM hive_context_next_block( 'context' );
    PERFORM hive_context_next_block( 'context' );
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
    INSERT INTO hive.table1( id, smth ) VALUES( 123, 'blabla' );
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
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' ) = 1, 'No expected id value in shadow table';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' AND hive_block_num = 1 ), 'Wrong block num';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 123 AND hs.smth = 'blabla' AND hive_operation_type = 0 ), 'Wrong operation type';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
