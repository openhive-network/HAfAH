DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );

    CREATE TABLE hive.table1( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    CREATE TABLE hive.table2( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );
    CREATE TABLE hive.table3( id INTEGER NOT NULL, smth TEXT NOT NULL ) INHERITS( hive.base );

    PERFORM hive_context_next_block( 'context' );

    -- one row inserted, ready to back from fork
    INSERT INTO hive.table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO hive.table2( id, smth ) VALUES( 223, 'blabla2' );
    INSERT INTO hive.table3( id, smth ) VALUES( 323, 'blabla3' );
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
    ASSERT ( SELECT COUNT(*) FROM hive.table1 ) = 0, 'Inserted row was not removed table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM hive.table2 ) = 0, 'Inserted row was not removed table2';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table2 ) = 0, 'Shadow table is not empty table2';

    ASSERT ( SELECT COUNT(*) FROM hive.table3 ) = 0, 'Inserted row was not removed table3';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table3 ) = 0, 'Shadow table is not empty table3';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();
