CREATE SCHEMA IF NOT EXISTS hive;

CREATE TABLE hive.base( hive_rowid BIGSERIAL );

CREATE TABLE IF NOT EXISTS hive.context(
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE TABLE IF NOT EXISTS hive.registered_tables(
   id SERIAL PRIMARY KEY,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   is_attached BOOL,
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
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);

CREATE TABLE IF NOT EXISTS hive.control_status(
      id BOOL PRIMARY KEY DEFAULT TRUE
    , back_from_fork BOOL NOT NULL
    , irreversible_block INTEGER NOT NULL
    , CONSTRAINT uq_hive_control_status CHECK( id )
);

INSERT INTO hive.control_status( id, back_from_fork, irreversible_block ) VALUES( TRUE, FALSE, 0 ) ON CONFLICT DO NOTHING;


