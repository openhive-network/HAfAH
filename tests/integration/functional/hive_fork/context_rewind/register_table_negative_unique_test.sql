DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
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
        CREATE TABLE table1( id SERIAL PRIMARY KEY, smth INTEGER, name TEXT, CONSTRAINT uq_smth UNIQUE(smth) ) INHERITS( hive.base );
        ASSERT FALSE, 'Did not catch expected exception';
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;
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
    ASSERT NOT EXISTS ( SELECT * FROM information_schema.tables WHERE table_schema='public' AND table_name = 'table1' ), 'The table was created';
END;
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
