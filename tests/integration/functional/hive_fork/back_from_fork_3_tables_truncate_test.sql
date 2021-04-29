DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    PERFORM hive.create_context( 'context' );

    CREATE TABLE A.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    CREATE TABLE B.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    CREATE TABLE table3( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );

    PERFORM hive.context_next_block( 'context' );

    INSERT INTO A.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO B.table1( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO table3( id, smth ) VALUES( 323, 'blabla3' );

    PERFORM hive.context_next_block( 'context' );

    TRUNCATE hive.shadow_a_table1; --to do not revert inserts
    TRUNCATE hive.shadow_b_table1; --to do not revert inserts
    TRUNCATE hive.shadow_public_table3; --to do not revert inserts

    TRUNCATE A.table1;
    TRUNCATE B.table1;
    TRUNCATE table3;
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
    PERFORM hive.back_from_fork();
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
    ASSERT ( SELECT COUNT(*) FROM A.table1 WHERE id=123 AND smth='blabla1' ) = 1, 'Deleted row was not reinserted table1';
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 1, 'Incorretc number of rows table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM B.table1 WHERE id=223 AND smth='blabla2' ) = 1, 'Deleted row was not reinserted table2';
    ASSERT ( SELECT COUNT(*) FROM B.table1 ) = 1, 'Incorretc number of rows table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 0, 'Shadow table is not empty table2';

    ASSERT ( SELECT COUNT(*) FROM table3 WHERE id=323 AND smth='blabla3' ) = 1, 'Deleted row was not reinserted table3';
    ASSERT ( SELECT COUNT(*) FROM table3 ) = 1, 'Incorretc number of rows table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table3 ) = 0, 'Shadow table is not empty table3';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
