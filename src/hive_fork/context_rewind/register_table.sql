CREATE OR REPLACE FUNCTION hive.create_revert_functions( _table_schema TEXT,  _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[] )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
__columns TEXT = array_to_string( _columns, ',' );
BEGIN
    -- rewind_insert
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_insert( _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            DELETE FROM %I.%I WHERE hive_rowid = _row_id;
        END;
        $$'
    , _table_schema,  _table_name
    , _table_schema,  _table_name
    );

    --rewind delete
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_delete( _operation_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            INSERT INTO %I.%I( %s )
            (
                SELECT %s
                FROM hive.%I st
                WHERE st.hive_operation_id = _operation_id
            );
        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION hive.%I_%I_revert_update( _operation_id BIGINT, _row_id BIGINT )
        RETURNS void
        LANGUAGE plpgsql
        VOLATILE
        AS
        $$
        BEGIN
            UPDATE %I.%I as t SET ( %s ) = (
            SELECT %s
            FROM hive.%I st1
            WHERE st1.hive_operation_id = _operation_id
            )
            WHERE t.hive_rowid = _row_id;
        END;
        $$'
    , _table_schema, _table_name
    , _table_schema, _table_name, __columns
    , __columns
    , _shadow_table_name
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.create_shadow_table( _table_schema TEXT,  _table_name TEXT )
    RETURNS TEXT -- name of the shadow table
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := 'shadow_' || lower(_table_schema) || '_' || lower(_table_name);
    __block_num_column_name TEXT := 'hive_block_num';
    __operation_column_name TEXT := 'hive_operation_type';
    __hive_rowid_column_name TEXT := 'hive_rowid';
    __operation_id_column_name TEXT :=  'hive_operation_id';
BEGIN
    EXECUTE format('CREATE TABLE hive.%I AS TABLE %I.%I', __shadow_table_name, _table_schema, _table_name );
    EXECUTE format('DELETE FROM hive.%I', __shadow_table_name ); --empty shadow table if origin table is not empty
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I hive.TRIGGER_OPERATION NOT NULL', __shadow_table_name, __operation_column_name );
    EXECUTE format('ALTER TABLE hive.%I ADD COLUMN %I BIGSERIAL PRIMARY KEY', __shadow_table_name, __operation_id_column_name );

    RETURN __shadow_table_name;
END;
$BODY$
;


-- creates a shadow table of registered table:
-- | [ table column1, table column2,.... ] | hive_block_num | hive_operation_type |
DROP FUNCTION IF EXISTS hive.register_table;
CREATE FUNCTION hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := 'shadow_' || lower(_table_schema) || '_' || lower(_table_name);
    __hive_insert_trigger_name TEXT := 'hive_insert_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_delete_trigger_name TEXT := 'hive_delete_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_update_trigger_name TEXT := 'hive_update_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_truncate_trigger_name TEXT := 'hive_truncate_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_insert TEXT := 'hive_on_table_trigger_insert_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_delete TEXT := 'hive_on_table_trigger_delete_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_update TEXT := 'hive_on_table_trigger_update_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_truncate TEXT := 'hive_on_table_trigger_truncate_' || lower(_table_schema) || '_' || _table_name;
    __new_sequence_name TEXT := 'seq_' || lower(_table_schema) || '_' || lower(_table_name);
    __context_id INTEGER := NULL;
    __registered_table_id INTEGER := NULL;
    __columns_names TEXT[];
BEGIN
    -- create a shadow table
    SELECT array_agg( iss.column_name::TEXT ) FROM information_schema.columns iss WHERE iss.table_schema=_table_schema AND iss.table_name=_table_name INTO __columns_names;
    SELECT hive.create_shadow_table(  _table_schema, _table_name ) INTO  __shadow_table_name;

    -- create and set separated sequence for hive.base part of the registered table
    EXECUTE format( 'CREATE SEQUENCE %I.%s', lower(_table_schema), __new_sequence_name );
    EXECUTE format( 'ALTER TABLE %I.%I ALTER COLUMN hive_rowid SET DEFAULT nextval( ''%s.%s'' )'
        , lower( _table_schema ), lower( _table_name )
        , lower(_table_schema)
        , __new_sequence_name
    );
    EXECUTE format( 'ALTER SEQUENCE %I.%I OWNED BY %I.%I.hive_rowid'
        , lower(_table_schema)
        , __new_sequence_name
        , lower(_table_schema)
        , lower( _table_name )
    );

    EXECUTE format('CREATE INDEX idx_%I_%I_row_id ON %I.%I(hive_rowid)', lower(_table_schema), lower(_table_name), lower(_table_schema), lower(_table_name) );

    -- insert information about new registered table
    INSERT INTO hive.registered_tables( context_id, origin_table_schema, origin_table_name, shadow_table_name, origin_table_columns )
    SELECT hc.id, tables.table_schema, tables.origin, tables.shadow, columns
    FROM ( SELECT hc.id FROM hive.context hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( _table_schema, _table_name, __shadow_table_name, __columns_names  )  ) as tables( table_schema, origin, shadow, columns ) ON TRUE
    RETURNING context_id, id INTO __context_id, __registered_table_id
    ;

    ASSERT __context_id IS NOT NULL, 'There is no context %', _context_name;
    ASSERT __registered_table_id IS NOT NULL;

    -- create trigger functions
    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hive.context WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;
            SELECT hc.current_block_num FROM hive.context hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hive.%I SELECT n.*,  __block_num, ''INSERT'' FROM new_table n ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_insert
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hive.context WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive.context hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hive.%I SELECT o.*, __block_num, ''DELETE'' FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_delete
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE OR REPLACE FUNCTION %s()
            RETURNS trigger
            LANGUAGE plpgsql
        AS
        $$
        DECLARE
           __block_num INTEGER := NULL;
           __values TEXT;
           __is_back_from_fork_in_progress BOOL := FALSE;
        BEGIN
            SELECT back_from_fork FROM hive.context WHERE id=%s INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive.context hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num <= 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
            END IF;

            INSERT INTO hive.%I SELECT o.*, __block_num, ''UPDATE'' FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_update
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
         'CREATE OR REPLACE FUNCTION %s()
             RETURNS trigger
             LANGUAGE plpgsql
         AS
         $$
         DECLARE
            __block_num INTEGER := NULL;
            __values TEXT;
            __is_back_from_fork_in_progress BOOL := FALSE;
         BEGIN
             SELECT back_from_fork FROM hive.context WHERE id=%s INTO __is_back_from_fork_in_progress;

             IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                 RETURN NEW;
             END IF;

             SELECT hc.current_block_num FROM hive.context hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

             IF ( __block_num <= 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive.context_next_block before table edition'';
             END IF;

             INSERT INTO hive.%I SELECT o.*, __block_num, ''DELETE'' FROM %I.%I o ON CONFLICT DO NOTHING;
             RETURN NEW;
         END;
         $$'
        , __hive_triggerfunction_name_truncate
        , __context_id
        , __shadow_table_name
        , _table_schema
        , _table_name
    );

    -- register insert trigger
    EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT ON %I.%I REFERENCING NEW TABLE AS NEW_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_insert_trigger_name
        , _table_schema
        , _table_name
        , __hive_triggerfunction_name_insert
        , __context_id
        , __shadow_table_name
    );

    -- register delete trigger
    EXECUTE format(
        'CREATE TRIGGER %I AFTER DELETE ON %I.%I REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_delete_trigger_name
        , _table_schema
        , _table_name
        , __hive_triggerfunction_name_delete
        , __context_id
        , __shadow_table_name
    );

    -- register update trigger
    EXECUTE format(
        'CREATE TRIGGER %I AFTER UPDATE ON %I.%I REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_update_trigger_name
        , _table_schema
        , _table_name
        , __hive_triggerfunction_name_update
        , __context_id
        , __shadow_table_name
    );

    -- register truncate trigger
    EXECUTE format(
        'CREATE TRIGGER %I BEFORE TRUNCATE ON %I.%I FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_truncate_trigger_name
        , _table_schema
        , _table_name
        , __hive_triggerfunction_name_truncate
        , __context_id
        , __shadow_table_name
    );

    PERFORM hive.create_revert_functions( _table_schema, _table_name, __shadow_table_name, __columns_names );

    -- save information about the triggers
    INSERT INTO hive.triggers( registered_table_id, trigger_name, function_name )
    VALUES
         ( __registered_table_id, __hive_insert_trigger_name, __hive_triggerfunction_name_insert )
       , ( __registered_table_id, __hive_delete_trigger_name, __hive_triggerfunction_name_delete )
       , ( __registered_table_id, __hive_update_trigger_name, __hive_triggerfunction_name_update )
       , ( __registered_table_id, __hive_truncate_trigger_name, __hive_triggerfunction_name_truncate )
    ;
END;
$BODY$
;
