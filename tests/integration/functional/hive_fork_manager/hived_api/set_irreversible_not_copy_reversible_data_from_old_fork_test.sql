DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
     , ( 1, 'OP 1', FALSE )
     , ( 2, 'OP 2', FALSE )
     , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    INSERT INTO hive.accounts_reversible
    VALUES ( 1, 'user', 2, 1 )
    ;

    INSERT INTO hive.transactions_reversible
    VALUES
    ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF',  1 )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
    ( 1, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: hive.operation, 1 )
    ;

    INSERT INTO hive.account_operations_reversible
    VALUES ( 2, 1, 1, 1, 1, 1 )
    ;

    INSERT INTO hive.transactions_multisig_reversible
    VALUES
    ( '\xDEED20', '\xBEEF20',  1 );

      INSERT INTO hive.applied_hardforks_reversible
    VALUES ( 1, 2, 1, 1 )
    ;


    PERFORM hive.back_from_fork( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD22', '\xCAFE22', '2016-06-22 19:10:25-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.set_irreversible( 2 );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT * FROM hive.transactions ), 'Transaction from abandoned block has landed in irreversible table';
    ASSERT NOT EXISTS ( SELECT * FROM hive.operations ), 'Operations from abandoned block has landed in irreversible table';
    ASSERT NOT EXISTS ( SELECT * FROM hive.transactions_multisig ), 'Signatures from abandoned block has landed in irreversible table';
    ASSERT NOT EXISTS ( SELECT * FROM hive.accounts WHERE id = 1 ), 'Accounts abandoned block has landed in irreversible table';
    ASSERT NOT EXISTS ( SELECT * FROM hive.account_operations ), 'Account_operations is not empty';
    ASSERT NOT EXISTS ( SELECT * FROM hive.applied_hardforks ), 'Hardforks from abandoned block has landed in irreversible table';
    ASSERT NOT EXISTS ( SELECT * FROM hive.blocks WHERE hash = '\xBADD20'::bytea ), 'Abandoned block has landed in irreversible table';
END;
$BODY$
;




