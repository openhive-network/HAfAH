CREATE SCHEMA IF NOT EXISTS hive;

DROP TYPE IF EXISTS hive.trigger_operation CASCADE;
CREATE TYPE hive.trigger_operation AS ENUM( 'INSERT', 'DELETE', 'UPDATE' );

CREATE TABLE IF NOT EXISTS hive.base( hive_rowid BIGSERIAL );

CREATE TABLE IF NOT EXISTS hive.contexts(
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    is_attached BOOL NOT NULL,
    back_from_fork BOOL NOT NULL DEFAULT FALSE,
    events_id BIGINT, -- no event is processed
    fork_id BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE TABLE IF NOT EXISTS hive.registered_tables(
   id SERIAL PRIMARY KEY,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive.contexts( id ),
   CONSTRAINT uq_registere_table UNIQUE( origin_table_schema, origin_table_name )
);

CREATE TABLE IF NOT EXISTS hive.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);


