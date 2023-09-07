CREATE OR REPLACE PROCEDURE test_hived_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.app_create_context( 'hived_context' );
        ASSERT FALSE, 'Hived can create a context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_exists( 'alice_context' );
        ASSERT FALSE, 'Hived can check if context exists';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( 'alice_context' );
        ASSERT FALSE, 'Hived can call app_next_block';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'alice_context' ] );
        ASSERT FALSE, 'Hived can call app_next_block as array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        CALL hive.appproc_context_detach( 'alice_context' );
        ASSERT FALSE, 'Hived can call app_context_detach';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        CALL hive.appproc_context_detach( ARRAY[ 'alice_context' ] );
        ASSERT FALSE, 'Hived can call app_context_detach array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        CREATE TABLE hived_table(id INT);
        PERFORM hive.app_register_table( 'hived_table' );
        ASSERT FALSE, 'Hived can call app_register_table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_set_non_forking( ARRAY[ 'alice_context' ] );
        ASSERT FALSE, 'Hived can call app_context_set_non_forking';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_set_non_forking( 'alice_context' );
            ASSERT FALSE, 'Hived can call app_context_set_non_forking';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_set_forking( ARRAY[ 'alice_context' ]  );
        ASSERT FALSE, 'Hived can call hive.app_context_set_forking';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_set_forking( 'alice_context' );
        ASSERT FALSE, 'Hived can call hive.app_context_set_forking';
    EXCEPTION WHEN OTHERS THEN
    END;

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
    PERFORM hive.app_create_context( 'alice_context_detached' );
    CALL hive.appproc_context_detach( 'alice_context_detached' );
    CREATE TABLE alice_table( id INT ) INHERITS( hive.alice_context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hive.blocks%ROWTYPE;
    __transaction1 hive.transactions%ROWTYPE;
    __transaction2 hive.transactions%ROWTYPE;
    __operation1_1 hive.operations%ROWTYPE;
    __operation2_1 hive.operations%ROWTYPE;
    __signatures1 hive.transactions_multisig%ROWTYPE;
    __signatures2 hive.transactions_multisig%ROWTYPE;
BEGIN
    BEGIN
        PERFORM hive.initialize_extension_data();
        ASSERT FALSE, 'An app can call hive.initialize_extension_data';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.back_from_fork( 1 );
        ASSERT FALSE, 'An app can call hive.back_from_fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp );
        __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
        __transaction2 = ( 101, 1::SMALLINT, '\xBEEF', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xDEED' );
        __operation1_1 = ( 1, 101, 0, 0, 1, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive.operation );
        __operation2_1 = ( 2, 101, 1, 0, 2, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive.operation );
        __signatures1 = ( '\xDEED', '\xFEED' );
        __signatures2 = ( '\xBEEF', '\xBABE' );
        PERFORM hive.push_block(
              __block
            , ARRAY[ __transaction1, __transaction2 ]
            , ARRAY[ __signatures1, __signatures2 ]
            , ARRAY[ __operation1_1, __operation2_1 ]
        );
        ASSERT FALSE, 'An app can call hive.push_block';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.set_irreversible( 100 );
        ASSERT FALSE, 'An app can call hive.set_irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.end_massive_sync();
        ASSERT FALSE, 'An app can call hive.end_massive_sync';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.copy_blocks_to_irreversible( 5, 8 );
        ASSERT FALSE, 'An app can call hive.copy_blocks_to_irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.copy_transactions_to_irreversible( 5, 8 );
        ASSERT FALSE, 'An app can call hive.copy_transactions_to_irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.copy_operations_to_irreversible( 5, 8 );
        ASSERT FALSE, 'An app can call hive.copy_operations_to_irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.copy_signatures_to_irreversible( 5, 8 );
        ASSERT FALSE, 'An app can call hive.copy_signatures_to_irreversible';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.remove_obsolete_reversible_data( 8 );
        ASSERT FALSE, 'An app can call hive.remove_obsolete_reversible_data';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.remove_unecessary_events( 8 );
        ASSERT FALSE, 'An app can call hive.remove_unecessary_events';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.refresh_irreversible_block_for_all_contexts( 8 );
        ASSERT FALSE, 'An app can call hive.refresh_irreversible_block_for_all_contexts';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;
