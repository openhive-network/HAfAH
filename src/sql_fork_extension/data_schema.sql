CREATE TABLE IF NOT EXISTS hive_contexts(
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE TABLE IF NOT EXISTS hive_registered_tables(
   id SERIAL PRIMARY KEY,
   context_id INTEGER NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive_contexts( id )
);

CREATE TABLE IF NOT EXISTS hive_triggers_operations(
   id SERIAL PRIMARY KEY,
   name TEXT NOT NULL,
   CONSTRAINT uq_hive_triggers_operations_name UNIQUE( name )
);

INSERT INTO hive_triggers_operations( id, name )
VALUES ( 0, 'INSERT' ), ( 1, 'DELETE' ), (2, 'UPDATE' )
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS hive_triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive_registered_tables( id )
);

CREATE TABLE IF NOT EXISTS hive_control_status(
      id BOOL PRIMARY KEY DEFAULT TRUE
    , back_from_fork BOOL NOT NULL
    , CONSTRAINT uq_hive_control_status CHECK( id )
);

INSERT INTO hive_control_status( id, back_from_fork ) VALUES( TRUE, FALSE ) ON CONFLICT DO NOTHING;

-- blocke registerd tables trigger
CREATE OR REPLACE FUNCTION hive_on_edit_registered_tables()
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
        JOIN hive_registered_tables hrt ON ( 'public.' || hrt.origin_table_name ) = tr.object_identity
        ) THEN
        RAISE EXCEPTION 'Cannot edit structure of register tables';
    END IF;
END;
$$
;

DROP EVENT TRIGGER IF EXISTS hive_block_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'ALTER TABLE' )
EXECUTE PROCEDURE hive_on_edit_registered_tables();


