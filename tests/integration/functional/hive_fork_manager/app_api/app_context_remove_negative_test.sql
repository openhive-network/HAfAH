
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA a;
    CREATE TABLE a.table1( id INT ) INHERITS( hive.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN

    BEGIN
        PERFORM hive.app_remove_context( 'not_existed_context' );
        ASSERT FALSE, 'Expected exception was not rised';
        EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'hive.row_id column exists';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_a_table1' ), 'shadow table exists';
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_a_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND shadow_table_name='shadow_a_table1' ), 'entry about';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.insert_trigger_a_table1'), 'Insert trigger not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_insert_a_table1'), 'Insert trigger function not dropped';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.delete_trigger_a_table1' ), 'Delete trigger not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_delete_a_table1') ,'Delete trigger function not dropped';
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive.update_trigger_a_table1' ), 'Update trigger not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_update_a_table1'), 'Update trigger function not dropped';
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'on_truncate_a_table1'), 'Truncate trigger function not dropped';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context' ), 'Context base table exists';
END;
$BODY$
;





