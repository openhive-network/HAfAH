DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- GOT PREPARED DATA SCHEMA
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
-- NOTHING TO DO
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
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_name  = 'hive_contexts' );
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_name  = 'hive_registered_tables' );
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_name  = 'hive_triggers_operations' );

    ASSERT EXISTS ( SELECT FROM hive_triggers_operations WHERE id = 0 AND name = 'INSERT' );
    ASSERT EXISTS ( SELECT FROM hive_triggers_operations WHERE id = 1 AND name = 'DELETE' );
    ASSERT EXISTS ( SELECT FROM hive_triggers_operations WHERE id = 2 AND name = 'UPDATE' );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
