DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE public.table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT );
    PERFORM hive_create_context( 'my_context' );
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
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
    BEGIN
        ALTER TABLE table1 ADD COLUMN test_column INTEGER;
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    ASSERT FALSE, 'Did not catch expected exception';
END;
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
    ASSERT NOT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1' AND iss.column_name='test_column'
        )
        , 'Column was inserted'
    ;
END;
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
