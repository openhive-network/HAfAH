DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    DROP TABLE IF EXISTS table1;
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT);
    PERFORM hive_create_context( 'my_context' );
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
    PERFORM hive_register_table( 'table1'::TEXT, 'my_context'::TEXT );
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
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_name  = 'hive_shadow_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='hive_shadow_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='hive_shadow_table1' AND column_name='hive_operation_type' AND data_type='smallint' );
    ASSERT EXISTS ( SELECT FROM hive_registered_tables WHERE origin_table_name='table1' AND shadow_table_name='hive_shadow_table1' );

    -- triggers
    ASSERT EXISTS ( SELECT FROM hive_triggers WHERE trigger_name='hive_insert_trigger_table1' AND function_name='hive_on_table_trigger_insert_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_insert_trigger_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_table1');

    ASSERT EXISTS ( SELECT FROM hive_triggers WHERE trigger_name='hive_delete_trigger_table1' AND function_name='hive_on_table_trigger_delete_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_delete_trigger_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_table1');

    ASSERT EXISTS ( SELECT FROM hive_triggers WHERE trigger_name='hive_update_trigger_table1' AND function_name='hive_on_table_trigger_update_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_update_trigger_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_table1');

    ASSERT EXISTS ( SELECT FROM hive_triggers WHERE trigger_name='hive_truncate_trigger_table1' AND function_name='hive_on_table_trigger_truncate_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_truncate_trigger_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_table1');
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
