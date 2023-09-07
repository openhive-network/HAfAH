﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context2' );
    PERFORM hive.context_create( 'context_attached' );
    PERFORM hive.context_next_block( 'context2' ); -- 0
    PERFORM hive.context_next_block( 'context2' ); -- 1
    PERFORM hive.context_next_block( 'context2' ); -- 2
    PERFORM hive.context_detach( 'context2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        -- no such context
        PERFORM hive.context_attach( 'context', 100 );
        ASSERT FALSE, "Did not catch expected exception for unexisted context";
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        -- block already processed
        PERFORM hive.context_attach( 'context2', 1 );
        ASSERT FALSE, "Did not catch expected exception when block num is to small";
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        -- atach already attached context
        PERFORM hive.context_attach( 'context_attached', 100 );
        ASSERT FALSE, "Did not catch expected exception when context was already attached";
    EXCEPTION WHEN OTHERS THEN
    END;
END
$BODY$
;



