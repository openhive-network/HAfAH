LOAD '$libdir/plugins/libfork_extension.so';

DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );

    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

    CREATE TRIGGER on_src_table_change_insert AFTER INSERT ON src_table
    REFERENCING NEW TABLE AS new_table
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
DECLARE
  StartTime timestamptz;
  EndTime timestamptz;
  Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
    FROM generate_series(1, 10000) AS gen(id)
         JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Duration in millisecs=%', Delta;
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
    ASSERT ( SELECT COUNT(*) FROM src_table ) = 10000, 'Not all rows were inserted';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();
