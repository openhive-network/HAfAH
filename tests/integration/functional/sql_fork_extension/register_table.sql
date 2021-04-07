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
    PERFORM hive_register_table( 'table1'::TEXT );
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_name  = 'hive_shadow_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='hive_shadow_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='hive_shadow_table1' AND column_name='hive_operation_type' AND data_type='smallint' );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
