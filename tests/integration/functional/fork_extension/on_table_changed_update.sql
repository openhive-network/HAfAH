--Example of fork_extention usage
--The plugin has not been finished yet, and at the moment it can be only considered as a demo version to show its potential

--0. Load the extension plugin
LOAD '$libdir/plugins/libfork_extension.so';

DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TABLE IF EXISTS table1;
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT);

    INSERT INTO table1 ( smth, name ) VALUES( 1, 'abc' );
    INSERT INTO table1 ( smth, name ) VALUES( 2, 'abc' );

    DROP TRIGGER IF EXISTS on_src_table1_change_update on table1;
    CREATE TRIGGER on_src_table1_change_update AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
            FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();
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
    UPDATE table1 SET smth=10;
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
    ASSERT ( SELECT COUNT(*) FROM hive_tuples ) = 2, 'TEST FAILED';
    ASSERT ( SELECT COUNT(*) FROM hive_tuples WHERE operation = 1 ) = 2, 'TEST FAILED';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
