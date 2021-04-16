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
    CREATE TABLE table2( id INTEGER NOT NULL, smth TEXT NOT NULL );
    CREATE TABLE table3( id INTEGER NOT NULL, smth TEXT NOT NULL );

    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'blabla3' );


    PERFORM hive_create_context( 'my_context' );

    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
    PERFORM hive_register_table( 'table2'::TEXT, 'my_context'::TEXT );
    PERFORM hive_register_table( 'table3'::TEXT, 'my_context'::TEXT );

    PERFORM hive_context_next_block( 'my_context' );

    UPDATE table1 SET smth='blabla4';
    UPDATE table2 SET smth='blabla5';
    UPDATE table3 SET smth='blabla6';
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
    ASSERT ( SELECT COUNT(*) FROM table1 WHERE id=123 AND smth='blabla1' AND hive_rowid=1 ) = 1, 'Updated row was not reverted table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 ) = 0, 'Shadow table is not empty table2';

    ASSERT ( SELECT COUNT(*) FROM table2 WHERE id=223 AND smth='blabla2' AND hive_rowid=1 ) = 1, 'Updated row was not reverted table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table2 ) = 0, 'Shadow table is not empty table2';

    ASSERT ( SELECT COUNT(*) FROM table3 WHERE id=323 AND smth='blabla3' AND hive_rowid=1 ) = 1, 'Updated row was not reverted table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table3 ) = 0, 'Shadow table is not empty table3';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
