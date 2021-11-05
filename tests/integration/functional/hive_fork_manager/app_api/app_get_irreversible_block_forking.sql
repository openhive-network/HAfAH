DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    -- hived inserts once irreversible block
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;
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
__result INT;
__blocks hive.blocks_range;
__curent_block INT;
BEGIN
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 0, 'hive.app_get_irreversible_block !=0 (1)';

        ASSERT ( SELECT hc.current_block_num FROM hive.contexts hc WHERE name = 'context' ) = 0, 'Wrng current block != 0(1)';

        SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- no events
        ASSERT ( SELECT hc.current_block_num FROM hive.contexts hc  WHERE name = 'context' ) = 0, 'Wrong current block != 0(2)';
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 0, 'hive.app_get_irreversible_block !=0 (2)';

        --hived ends massive sync - irreversible = 1
        PERFORM hive.end_massive_sync( 1 );
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 0, 'hive.app_get_irreversible_block !=0 (3)';

        SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- massive sync event
        RAISE NOTICE 'Blocks range after MASSIVE_SYNC = %', __blocks;

        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (1)';

        PERFORM hive.push_block(
            ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp )
            , NULL
            , NULL
            , NULL
            , NULL
            , NULL
        );
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (2)';

        PERFORM hive.push_block(
            ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp )
            , NULL
            , NULL
            , NULL
            , NULL
            , NULL
        );
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (3)';

        PERFORM hive.set_irreversible( 2 );
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 1, 'hive.app_get_irreversible_block !=1 (4)';

        -- we are next after massive sync
        PERFORM hive.app_next_block( 'context' ); -- block 2
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (5)';

        PERFORM hive.app_next_block( 'context' ); -- block 3
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=1 (6)';

        PERFORM hive.app_next_block( 'context' ); -- SET IRREVERSIBLE 2
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (1)';

        PERFORM hive.app_next_block( 'context' ); -- NO EVENT
        ASSERT ( SELECT hive.app_get_irreversible_block( 'context' ) ) = 2, 'hive.app_get_irreversible_block !=2 (2)';
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
    --NOTHING TO CHECK HERE
END
$BODY$
;




