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
    PERFORM hive.context_create( 'context', 1 );
    PERFORM hive.context_create( 'context2', 5 );
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
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'context' AND current_block_num = 1 AND irreversible_block = 1 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'context2' AND current_block_num = 5 AND irreversible_block = 5 AND is_attached = TRUE );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
