DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TABLE IF EXISTS table1;
    CREATE TABLE table1( id INTEGER NOT NULL, smth TEXT NOT NULL );
    PERFORM hive_create_context( 'my_context' );
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
    PERFORM hive_context_next_block( 'my_context' );
    PERFORM hive_context_next_block( 'my_context' );
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
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
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
