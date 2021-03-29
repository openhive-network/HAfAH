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
    --1. Lets create some not trivial tables
    --1.a custom type to proof that they can be supported
    DROP TYPE IF EXISTS custom_type CASCADE;
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );
    --1.b a table with different kind of column types. It will be filled by the client
    DROP TABLE IF EXISTS src_table;
    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

    DROP TABLE IF EXISTS pattern_table;
    CREATE TABLE pattern_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

    --3. Make operations on src_table
    --3.a Insert 10000 rows to src table, each of them will be copied to the tuples table
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 100) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    --3.b save table content as a pattern
    INSERT INTO pattern_table SELECT * FROM src_table;

    --2. Create triggers ( function on_table_change()  was added by the plugin during its loading )
    DROP TRIGGER IF EXISTS on_src_table_change_insert on src_table;
    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON src_table
        REFERENCING NEW TABLE AS new_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table_change_delte on src_table;
    CREATE TRIGGER on_src_table_change_delte AFTER DELETE ON src_table
        REFERENCING OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

    DROP TRIGGER IF EXISTS on_src_table_change_update on src_table;
    CREATE TRIGGER on_src_table_change_update AFTER UPDATE ON src_table
        REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
        FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();
    -- I)
    -- update some rows
    UPDATE src_table SET name = 'changed_name' WHERE id % 5 = 0;
    --delete some rows
    DELETE FROM src_table WHERE id % 15 = 0;
    --insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    -- II)
    -- update once again
    UPDATE src_table SET name = 'changed_name2' WHERE id % 7 = 0;
    -- insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 50) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    -- delete
    DELETE FROM src_table WHERE id % 11 = 0;

    -- III)
    --insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 50) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    -- update once again
    UPDATE src_table SET name = 'changed_name3' WHERE id % 3 = 0;
    -- delete
    DELETE FROM src_table WHERE id % 13 = 0;

    -- IV)
    --insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 50) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    -- delete
    DELETE FROM src_table WHERE id % 17 = 0;
    -- update once again
    UPDATE src_table SET name = 'changed_name4' WHERE id % 17 = 0;

    -- V)
    -- delete
    DELETE FROM src_table WHERE id % 19 = 0;
    --insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 50) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    -- update once again
    UPDATE src_table SET name = 'changed_name5' WHERE id % 23 = 0;

    -- VI)
    -- delete
    DELETE FROM src_table WHERE id % 31 = 0;
    -- update once again
    UPDATE src_table SET name = 'changed_name5' WHERE id % 29 = 0;
    --insert
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 50) AS gen(id)
             JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;

    ASSERT EXISTS( SELECT * FROM src_table EXCEPT SELECT * FROM pattern_table ) = TRUE, 'ERROR: Pattern table is equal to the table after changes';
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
    ASSERT EXISTS ( SELECT * FROM src_table EXCEPT SELECT * FROM pattern_table ) = FALSE, 'TEST FAILED';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
