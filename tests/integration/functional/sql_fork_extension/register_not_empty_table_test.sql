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
    INSERT INTO table1(smth, name) VALUES( 123, 'NAME' );
    PERFORM hive_create_context( 'my_context' );
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
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_table1' );
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_table1 ) = 0, 'The shadow table must be empty';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
