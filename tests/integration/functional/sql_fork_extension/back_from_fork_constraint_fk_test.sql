DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TABLE IF EXISTS table1;
    CREATE TABLE table1( id INTEGER PRIMARY KEY, smth TEXT NOT NULL );
    CREATE TABLE table2(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , table1_id INTEGER NOT NULL
        , CONSTRAINT fk_table2_table1_id FOREIGN KEY( table1_id ) REFERENCES table1(id) DEFERRABLE
    );

    PERFORM hive_create_context( 'my_context' );

    -- registration order is important for the test because first registered table is first rewinded
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
    PERFORM hive_register_table( 'table2'::TEXT, 'my_context'::TEXT );

    PERFORM hive_context_next_block( 'my_context' );

    -- one row inserted, ready to back from fork
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth, table1_id ) VALUES( 223, 'blabla2', 123 );
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
    -- because table1 will be first rewinded table2 will stay with incorrect FK for tabe1(id)
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
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 0, 'Inserted row was not removed table1';
    ASSERT ( SELECT COUNT(*) FROM hive.hive_shadow_table1 ) = 0, 'Shadow table is not empty table1';

    ASSERT ( SELECT COUNT(*) FROM table2 ) = 0, 'Inserted row was not removed table2';
    ASSERT ( SELECT COUNT(*) FROM hive.hive_shadow_table2 ) = 0, 'Shadow table is not empty table2';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();
