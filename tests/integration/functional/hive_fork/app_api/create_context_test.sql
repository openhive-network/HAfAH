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
    PERFORM hive.app_create_context( 'context' );

    -- check if correct irreversibe block is set
    INSERT INTO hive.blocks VALUES( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp );
    PERFORM hive.app_create_context( 'context2');
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
    ASSERT EXISTS ( SELECT FROM hive.app_context WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 0 AND events_id IS NULL AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.app_context WHERE name = 'context2' AND current_block_num = 0 AND irreversible_block = 101  AND events_id IS NULL AND is_attached = TRUE );

    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'context2' AND current_block_num = 0 AND irreversible_block = 101 AND is_attached = TRUE );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
