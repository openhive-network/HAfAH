CREATE TABLE hive_contexts(
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE TABLE hive_registered_tables(
   id SERIAL PRIMARY KEY,
   context_id INTEGER NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive_contexts( id )
);

CREATE TABLE hive_triggers_operations(
   id SERIAL PRIMARY KEY,
   name TEXT NOT NULL,
   CONSTRAINT uq_hive_triggers_operations_name UNIQUE( name )
);

INSERT INTO hive_triggers_operations( id, name )
VALUES ( 0, 'INSERT' ), ( 1, 'DELETE' ), (2, 'UPDATE' );
