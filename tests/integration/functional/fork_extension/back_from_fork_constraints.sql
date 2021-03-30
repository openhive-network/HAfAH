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
    DROP TABLE IF EXISTS table1 CASCADE;
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT);

    DROP TABLE IF EXISTS pattern_table1 CASCADE;
    CREATE TABLE pattern_table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT);

    DROP TABLE IF EXISTS table2 CASCADE;
    CREATE TABLE table2(
         id SERIAL PRIMARY KEY,
         name TEXT,
         smth integer,
        CONSTRAINT fk_table1 FOREIGN KEY(smth) REFERENCES table1(id)
    );

    DROP TABLE IF EXISTS pattern_table2 CASCADE;
    CREATE TABLE pattern_table2(id  SERIAL PRIMARY KEY, name TEXT, smth integer);

    --3. Make operations on src_table
    --3.a Insert 1000 rows to src table, each of them will be copied to the tuples table
    INSERT INTO table1( id, smth, name ) VALUES( 1, 2, 'tmp' );
    INSERT INTO table2( id, name, smth ) VALUES( 5, 'tmp2', 1 );

    INSERT INTO pattern_table1 SELECT * FROM table1;
    INSERT INTO pattern_table2 SELECT * FROM table2;

    --2. Create triggers ( function on_table_change()  was added by the plugin during its loading )
    DROP TRIGGER IF EXISTS on_src_table1_change_insert on table1;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON table1
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table1_change_delte on table1;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON table1
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table1_change_update on table1;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();
    ----------------------------------------------------------------------------------------
    DROP TRIGGER IF EXISTS on_src_table2_change_insert on table2;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON table2
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table2_change_delte on table2;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON table2
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table2_change_update on table2;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON table2
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    UPDATE table1 SET name = 'changed_name1';
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
    -- back from fork - revert all the insersts above
    PERFORM back_from_fork();
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
    ASSERT EXISTS ( SELECT * FROM table1 EXCEPT SELECT * FROM pattern_table1 ) = FALSE, 'Table does not back to its prevoius state';
    ASSERT EXISTS ( SELECT * FROM table2 EXCEPT SELECT * FROM pattern_table2 ) = FALSE, 'Table does not back to its prevoius state';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
