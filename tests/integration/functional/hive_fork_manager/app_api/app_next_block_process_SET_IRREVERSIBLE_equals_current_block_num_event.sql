DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:24-07'::timestamp )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
    ;

    INSERT INTO hive.events_queue
    VALUES
          ( 1, 'NEW_IRREVERSIBLE', 3)
        , ( 2, 'NEW_BLOCK', 5)
    ;

    INSERT INTO hive.contexts
    VALUES (1, 'context', 3, 3, true, false, 0, 1, 'user', null );
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
    __result hive.blocks_range;
BEGIN
    -- NOTHING TO DO HERE
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
DECLARE
    __result hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __result; -- process NEW IRREVERSIBLE
    ASSERT __result IS NULL, 'Processing new irreversibel returns NULL';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __result; -- process NEW IRREVERSIBLE
    RAISE NOTICE 'result=%', __result;
    ASSERT __result = (2,4), 'Not return (2,4)';


END
$BODY$
;




