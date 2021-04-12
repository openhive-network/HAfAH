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

    INSERT INTO table1( id, smth ) VALUES( 123, 'balbla1' );
    INSERT INTO table2( id, smth ) VALUES( 223, 'balbla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'balbla3' );

    PERFORM hive_create_context( 'my_context' );

    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
    PERFORM hive_register_table( 'table2'::TEXT, 'my_context'::TEXT );
    PERFORM hive_register_table( 'table3'::TEXT, 'my_context'::TEXT );

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
    DELETE FROM table1;
    DELETE FROM table2;
    DELETE FROM table3;
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
    ASSERT EXISTS ( SELECT FROM hive_shadow_table1 hs WHERE hs.id = 123 AND hs.smth='balbla1' AND hive_operation_type = 1 AND hive_rowid = 1 AND hive_block_num = 0 ), 'Lack of expected operation table1';
    ASSERT ( SELECT COUNT(*) FROM hive_shadow_table1 ) = 1, 'Too many rows in shadow table1';

    ASSERT EXISTS ( SELECT FROM hive_shadow_table2 hs WHERE hs.id = 223 AND hs.smth='balbla2' AND hive_operation_type = 1 AND hive_rowid = 1  AND hive_block_num = 0 ), 'Lack of expected operation table2';
    ASSERT ( SELECT COUNT(*) FROM hive_shadow_table1 ) = 1, 'Too many rows in shadow table2';

    ASSERT EXISTS ( SELECT FROM hive_shadow_table3 hs WHERE hs.id = 323 AND hs.smth='balbla3' AND hive_operation_type = 1 AND hive_rowid = 1  AND hive_block_num = 0 ), 'Lack of expected operation table3';
    ASSERT ( SELECT COUNT(*) FROM hive_shadow_table1 ) = 1, 'Too many rows in shadow table3';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
