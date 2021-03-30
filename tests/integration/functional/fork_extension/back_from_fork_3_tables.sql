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

    DROP TABLE IF EXISTS pattern_table1;
    CREATE TABLE pattern_table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT);

    DROP TABLE IF EXISTS table2;
    CREATE TABLE table2(id  SERIAL PRIMARY KEY, name TEXT, smth integer);

    DROP TABLE IF EXISTS pattern_table2;
    CREATE TABLE pattern_table2(id  SERIAL PRIMARY KEY, name TEXT, smth integer);

    DROP TABLE IF EXISTS table3;
    CREATE TABLE table3(id SERIAL PRIMARY KEY, smth1 integer, smth2 integer);

    DROP TABLE IF EXISTS pattern_table3;
    CREATE TABLE pattern_table3(id  SERIAL PRIMARY KEY, smth1 integer, smth2 integer);

    --3. Make operations on src_table
    --3.a Insert 1000 rows to src table, each of them will be copied to the tuples table
    INSERT INTO table1 ( smth, name )
    SELECT gen.id, val.name
    FROM generate_series(1, 1000) AS gen(id)
             JOIN ( VALUES( 'temp1' ) ) as val(name) ON True;

    INSERT INTO pattern_table1 SELECT * FROM table1;

    INSERT INTO table2 ( smth, name )
    SELECT gen.id, val.name
    FROM generate_series(2000, 3000) AS gen(id)
             JOIN ( VALUES( 'temp2' ) ) as val(name) ON True;

    INSERT INTO pattern_table2 SELECT * FROM table2;

    INSERT INTO table3 ( smth1, smth2 )
    SELECT gen.id, gen.id + 2
    FROM generate_series(3000, 4000) AS gen(id);

    INSERT INTO pattern_table3 SELECT * FROM table3;

    --2. Create triggers ( function hive_on_table_change()  was added by the plugin during its loading )
    DROP TRIGGER IF EXISTS on_src_table1_change_insert on table1;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON table1
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table1_change_delte on table1;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON table1
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table1_change_update on table1;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();
    ----------------------------------------------------------------------------------------
    DROP TRIGGER IF EXISTS on_src_table2_change_insert on table2;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON table2
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table2_change_delte on table2;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON table2
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table2_change_update on table2;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON table2
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();
    --------------------------------------------------------------------------------------
    DROP TRIGGER IF EXISTS on_src_table3_change_insert on table3;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON table3
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table3_change_delte on table3;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON table3
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();

    DROP TRIGGER IF EXISTS on_src_table3_change_update on table3;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON table3
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE hive_on_table_change();


    -- I)
    -- update some rows
    UPDATE table1 SET name = 'changed_name1' WHERE id % 5 = 0;
    UPDATE table2 SET name = 'changed_name2' WHERE id % 5 = 0;
    UPDATE table3 SET smth2 = 11 WHERE id % 5 = 0;
    -- insert some rows
    INSERT INTO table3 ( smth1, smth2 ) SELECT gen.id, gen.id + 2 FROM generate_series(5000, 5000 + 5) AS gen(id);
    INSERT INTO table2 ( smth, name ) SELECT gen.id, val.name FROM generate_series( 6000, 6000 + 7) AS gen(id) JOIN ( VALUES( 'inserted2' ) ) as val(name) ON True;
    INSERT INTO table1 ( smth, name ) SELECT gen.id, val.name FROM generate_series(7000, 7000 + 11) AS gen(id) JOIN ( VALUES( 'inserted1' ) ) as val(name) ON True;
    --delete sme rows
    DELETE FROM table2 WHERE id % 35 = 0;
    DELETE FROM table1 WHERE id % 55 = 0;
    DELETE FROM table3 WHERE id % 10 = 0;

    --check tahat tables are equal
    ASSERT EXISTS( SELECT * FROM table1 EXCEPT SELECT * FROM pattern_table1 ) = TRUE, 'Pattern tables are equal src table before changes';
    ASSERT EXISTS( SELECT * FROM table2 EXCEPT SELECT * FROM pattern_table2 ) = TRUE, 'Pattern tables are equal src table before changes';
    ASSERT EXISTS( SELECT * FROM table3 EXCEPT SELECT * FROM pattern_table3 ) = TRUE, 'Pattern tables are equal src table before changes';
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
    ASSERT EXISTS ( SELECT * FROM table1 EXCEPT SELECT * FROM pattern_table1 ) = FALSE, 'Table does not back to its prevoius state';
    ASSERT EXISTS ( SELECT * FROM table2 EXCEPT SELECT * FROM pattern_table2 ) = FALSE, 'Table does not back to its prevoius state';
    ASSERT EXISTS ( SELECT * FROM table3 EXCEPT SELECT * FROM pattern_table3 ) = FALSE, 'Table does not back to its prevoius state';

END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
