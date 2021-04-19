DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE public.table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT );
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
    DROP TABLE table1;
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
    -- we only noticed about rmoving registered table, there is no possibility to prevent DROP a table
    -- because  event trigger 'sql drop' arrives at the moment when the table is already removed.
    -- This sitation should not bother us, since we want to register table with CREATE TABLE command, so DROP is
    -- a good choice to make unregister
    ASSERT NOT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_name='table1'
        )
        , 'Table was removed'
    ;
END;
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
