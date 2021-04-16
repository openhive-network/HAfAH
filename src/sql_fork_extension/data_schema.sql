CREATE SCHEMA IF NOT EXISTS hive;


CREATE TABLE IF NOT EXISTS hive.context(
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE TABLE IF NOT EXISTS hive.registered_tables(
   id SERIAL PRIMARY KEY,
   context_id INTEGER NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive.context( id )
);

CREATE TABLE IF NOT EXISTS hive.triggers_operations(
   id SERIAL PRIMARY KEY,
   name TEXT NOT NULL,
   CONSTRAINT uq_hive_triggers_operations_name UNIQUE( name )
);

INSERT INTO hive.triggers_operations( id, name )
VALUES ( 0, 'INSERT' ), ( 1, 'DELETE' ), (2, 'UPDATE' )
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS hive.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive.registered_tables( id )
);

CREATE TABLE IF NOT EXISTS hive.control_status(
      id BOOL PRIMARY KEY DEFAULT TRUE
    , back_from_fork BOOL NOT NULL
    , CONSTRAINT uq_hive_control_status CHECK( id )
);

INSERT INTO hive.control_status( id, back_from_fork ) VALUES( TRUE, FALSE ) ON CONFLICT DO NOTHING;

-- blocke registerd tables trigger
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
__dropped_tables TEXT := NULL;
__dropped_tables_orig TEXT := NULL;
__r RECORD;
BEGIN
    SELECT STRING_AGG( DISTINCT(tr.object_identity), ',' )  FROM
    ( SELECT * FROM pg_event_trigger_dropped_objects() ) as tr
        JOIN hive.registered_tables hrt ON ( 'public.' || hrt.origin_table_name ) = tr.object_identity
    INTO __dropped_tables;

    IF __dropped_tables IS NOT NULL THEN
        RAISE WARNING 'Registered table(S) were dropped: %', __dropped_tables;
    END IF;
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


