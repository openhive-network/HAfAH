-- block registerd tables trigger
CREATE OR REPLACE FUNCTION hive.on_edit_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__result BOOL;
__r RECORD;
BEGIN
    IF EXISTS (
        SELECT * FROM
        ( SELECT * FROM pg_event_trigger_ddl_commands() ) as tr
        JOIN hive.registered_tables hrt ON ( 'public.' || hrt.origin_table_name ) = tr.object_identity
        ) THEN
        RAISE EXCEPTION 'Cannot edit structure of registered tables';
END IF;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_drop_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__dropped_tables TEXT[];
__r RECORD;
__table TEXT;
BEGIN
    SELECT ARRAY_AGG( DISTINCT(tr.object_name) )  FROM
    ( SELECT * FROM pg_event_trigger_dropped_objects() ) as tr
        JOIN hive.registered_tables hrt ON hrt.origin_table_name  = tr.object_name
    INTO __dropped_tables;

    IF ARRAY_LENGTH( __dropped_tables, 1 ) > 0 THEN
        FOREACH __table IN ARRAY __dropped_tables
        LOOP
        PERFORM hive_clean_after_uregister_table( __table );
END LOOP;

        RAISE WARNING 'Registered table(S) were dropped: %', ARRAY_TO_STRING( __dropped_tables, ',' );
END IF;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_create_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    PERFORM hive.register_table( replace( lower( tr.object_identity ), 'hive.', ''), 'context' )
    FROM pg_event_trigger_ddl_commands() as tr
    WHERE tr.schema_name='hive' AND tr.object_type = 'table';
END;
$$
;

DROP EVENT TRIGGER IF EXISTS hive_block_edit_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_edit_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'ALTER TABLE' )
EXECUTE PROCEDURE hive.on_edit_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_block_drop_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_drop_registered_tables_trigger ON sql_drop
WHEN TAG IN ( 'DROP TABLE' )
EXECUTE PROCEDURE hive.on_drop_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_create_registered_tables_trigger;
CREATE EVENT TRIGGER hive_create_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'CREATE TABLE' )
EXECUTE PROCEDURE hive.on_create_tables();