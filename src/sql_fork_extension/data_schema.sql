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
   name TEXT NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive_registered_tables( id )
);

CREATE TABLE IF NOT EXISTS hive_control_status(
      id BOOL PRIMARY KEY DEFAULT TRUE
    , back_from_fork BOOL NOT NULL
    , CONSTRAINT uq_hive_control_status CHECK( id )
);

INSERT INTO hive_control_status( id, back_from_fork ) VALUES( TRUE, FALSE ) ON CONFLICT DO NOTHING;
