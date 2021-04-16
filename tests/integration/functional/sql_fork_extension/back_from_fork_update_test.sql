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
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla' );
    PERFORM hive_create_context( 'my_context' );
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
    PERFORM hive_context_next_block( 'my_context' );

    UPDATE table1 SET id=321;
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
    PERFORM hive_back_from_fork();
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=123 ) = 1, 'Updated row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
