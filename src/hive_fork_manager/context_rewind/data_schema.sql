CREATE SCHEMA IF NOT EXISTS hive;

DO
$$
    BEGIN
    CREATE DOMAIN hive.context_name AS TEXT;
    EXCEPTION
            WHEN duplicate_object THEN null;
    END
$$;


DO
$$
    BEGIN
        CREATE TYPE hive.trigger_operation AS ENUM( 'INSERT', 'DELETE', 'UPDATE' );
        EXCEPTION
            WHEN duplicate_object THEN null;
    END
$$;

CREATE TABLE IF NOT EXISTS hive.contexts(
    id SERIAL NOT NULL,
    name hive.context_name NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    is_attached BOOL NOT NULL,
    back_from_fork BOOL NOT NULL DEFAULT FALSE,
    events_id BIGINT, -- no event is processed
    fork_id BIGINT NOT NULL DEFAULT 1,
    owner NAME NOT NULL,
    CONSTRAINT pk_hive_contexts PRIMARY KEY( id ),
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);

CREATE INDEX IF NOT EXISTS hive_contexts_owner_idx ON hive.contexts( owner );

CREATE TABLE IF NOT EXISTS hive.registered_tables(
   id SERIAL NOT NULL,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT pk_hive_registered_tables PRIMARY KEY( id ),
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive.contexts( id ),
   CONSTRAINT uq_hive_registered_tables_register_table UNIQUE( origin_table_schema, origin_table_name )
);


CREATE INDEX IF NOT EXISTS hive_registered_tables_context_idx ON hive.registered_tables( context_id );
CREATE INDEX IF NOT EXISTS hive_registered_tables_owder_idx ON hive.registered_tables( owner );


CREATE TABLE IF NOT EXISTS hive.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);

CREATE INDEX IF NOT EXISTS hive_registered_triggers_table_id ON hive.triggers( registered_table_id );
CREATE INDEX IF NOT EXISTS hive_triggers_owner_idx ON hive.triggers( owner );





