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
    PERFORM hive.create_context( 'my_context' );
    PERFORM hive.register_table( 'table1'::TEXT, 'my_context'::TEXT );
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
    PERFORM hive_context_next_block( 'my_context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table1( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table1( id, smth ) VALUES( 323, 'blabla3' );
    PERFORM hive_context_next_block( 'my_context' );
    UPDATE table1 SET id=423 WHERE id=123;
    UPDATE table1 SET id=523 WHERE id=223;
    UPDATE table1 SET id=623 WHERE id=323;
    PERFORM hive_context_next_block( 'my_context' );
    DELETE FROM table1 WHERE id=423;
    DELETE FROM table1 WHERE id=523;
    DELETE FROM table1 WHERE id=623;
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
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 123 AND hs.hive_rowid = 1 AND hs.hive_block_num = 0 AND hs.hive_operation_type = 0 ), 'Lack of insert operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 223 AND hs.hive_rowid = 2 AND hs.hive_block_num = 0 AND hs.hive_operation_type = 0 ), 'Lack of insert operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 323 AND hs.hive_rowid = 3 AND hs.hive_block_num = 0 AND hs.hive_operation_type = 0 ), 'Lack of insert operation';

    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 123 AND hs.hive_rowid = 1 AND hs.hive_block_num = 1 AND hs.hive_operation_type = 2 ), 'Lack of update operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 223 AND hs.hive_rowid = 2 AND hs.hive_block_num = 1 AND hs.hive_operation_type = 2 ), 'Lack of update operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 323 AND hs.hive_rowid = 3 AND hs.hive_block_num = 1 AND hs.hive_operation_type = 2 ), 'Lack of update operation';

    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 423 AND hs.hive_rowid = 1 AND hs.hive_block_num = 2 AND hs.hive_operation_type = 1 ), 'Lack of delete operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 523 AND hs.hive_rowid = 2 AND hs.hive_block_num = 2 AND hs.hive_operation_type = 1 ), 'Lack of delete operation';
    ASSERT EXISTS ( SELECT FROM hive.shadow_table1 hs WHERE hs.id = 623 AND hs.hive_rowid = 3 AND hs.hive_block_num = 2 AND hs.hive_operation_type = 1 ), 'Lack of delete operation';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 ) = 9;
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
