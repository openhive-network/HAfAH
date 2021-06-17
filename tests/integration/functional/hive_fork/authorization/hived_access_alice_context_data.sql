DROP FUNCTION IF EXISTS hived_test_given;
CREATE FUNCTION hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
    ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;
    PERFORM hive.end_massive_sync();
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_when;
CREATE FUNCTION hived_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DELETE FROM hive.contexts WHERE name = 'alice_context';
    UPDATE hive.contexts SET current_block_num = 100 WHERE name = 'alice_context';
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- hived need to see context data to correctly tailore reversible blocks and events queue
    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name='alice_context' ), 'Hived does not see Alice''s context';

    BEGIN
        CREATE TABLE hived_table(id INT ) INHERITS( hive.alice_context );
        ASSERT FALSE, 'Hived can register tabkle in Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.shadow_public_alice_table;
        ASSERT FALSE, 'Hived can edit Alice''s shadow table';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
    PERFORM hive.app_create_context( 'alice_context_detached' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );
    CREATE TABLE alice_table( id INT ) INHERITS( hive.alice_context );
    PERFORM hive.app_next_block( 'alice_context' );
    INSERT INTO alice_table VALUES( 10 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name = 'alice_context' ), 'Alice''s context was removed by hived';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name = 'alice_context' ) = 1, 'Alice''s context was updated by hived';
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS BOB
END;
$BODY$
;
