-- creates a shadow table of registered table:
-- | [ table column1, table column2,.... ] | hive_block_num | hive_operation_type |
DROP FUNCTION IF EXISTS hive_register_table;
CREATE FUNCTION hive_register_table( _table_name TEXT, _context_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := 'hive_shadow_' || _table_name;
    __block_num_column_name TEXT := 'hive_block_num';
    __operation_column_name TEXT := 'hive_operation_type';
    __hive_rowid_column_name TEXT := 'hive_rowid';
    __hive_insert_trigger_name TEXT := 'hive_insert_trigger_' || _table_name;
    __hive_delete_trigger_name TEXT := 'hive_delete_trigger_' || _table_name;
    __hive_update_trigger_name TEXT := 'hive_update_trigger_' || _table_name;
    __hive_truncate_trigger_name TEXT := 'hive_truncate_trigger_' || _table_name;
    __hive_triggerfunction_name_insert TEXT := 'hive_on_table_trigger_insert_' || _table_name;
    __hive_triggerfunction_name_delete TEXT := 'hive_on_table_trigger_delete_' || _table_name;
    __hive_triggerfunction_name_update TEXT := 'hive_on_table_trigger_update_' || _table_name;
    __hive_triggerfunction_name_truncate TEXT := 'hive_on_table_trigger_truncate_' || _table_name;
    __context_id INTEGER := NULL;
    __registered_table_id INTEGER := NULL;
    __columns_names TEXT[];
BEGIN
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I BIGSERIAL', _table_name, __hive_rowid_column_name );

    SELECT array_agg( iss.column_name::TEXT ) FROM information_schema.columns iss WHERE iss.table_name=_table_name INTO __columns_names;
    EXECUTE format('CREATE TABLE %I AS TABLE %I', __shadow_table_name, _table_name );
    EXECUTE format('DELETE FROM %I', __shadow_table_name ); --empty shadow table if origin table is not empty
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I SMALLINT NOT NULL', __shadow_table_name, __operation_column_name );
    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT uk_%s UNIQUE( %I, %I )', __shadow_table_name, __shadow_table_name, __block_num_column_name, __hive_rowid_column_name );

    INSERT INTO hive_registered_tables( context_id, origin_table_name, shadow_table_name, origin_table_columns )
    SELECT hc.id, tables.origin, tables.shadow, columns
    FROM ( SELECT hc.id FROM hive_contexts hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( _table_name, __shadow_table_name, __columns_names  )  ) as tables( origin, shadow, columns ) ON TRUE
    RETURNING context_id, id INTO __context_id, __registered_table_id
    ;

    ASSERT __context_id IS NOT NULL;
    ASSERT __registered_table_id IS NOT NULL;

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
            SELECT back_from_fork FROM hive_control_status INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num < 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive_context_next_block before table edition'';
            END IF;

            INSERT INTO %I SELECT n.*,  __block_num, 0 FROM new_table n ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_insert
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
        SELECT back_from_fork FROM hive_control_status INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num < 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive_context_next_block before table edition'';
            END IF;

            INSERT INTO %I SELECT o.*, __block_num, 1 FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_delete
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
        SELECT back_from_fork FROM hive_control_status INTO __is_back_from_fork_in_progress;

            IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                RETURN NEW;
            END IF;

            SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

            IF ( __block_num < 0 ) THEN
                RAISE EXCEPTION ''Did not execute hive_context_next_block before table edition'';
            END IF;

            INSERT INTO %I SELECT o.*, __block_num, 2 FROM old_table o ON CONFLICT DO NOTHING;
            RETURN NEW;
        END;
        $$'
        , __hive_triggerfunction_name_update
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
         SELECT back_from_fork FROM hive_control_status INTO __is_back_from_fork_in_progress;

             IF ( __is_back_from_fork_in_progress = TRUE ) THEN
                 RETURN NEW;
             END IF;

             SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

             IF ( __block_num < 0 ) THEN
                 RAISE EXCEPTION ''Did not execute hive_context_next_block before table edition'';
             END IF;

             INSERT INTO %I SELECT o.*, __block_num, 1 FROM %I o ON CONFLICT DO NOTHING;
             RETURN NEW;
         END;
         $$'
        , __hive_triggerfunction_name_truncate
        , __shadow_table_name
        , _table_name
    );

    -- register insert trigger
    EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT ON %I REFERENCING NEW TABLE AS NEW_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_insert_trigger_name
        , _table_name
        , __hive_triggerfunction_name_insert
        , __context_id
        , __shadow_table_name
    );

    -- register delete trigger
    EXECUTE format(
        'CREATE TRIGGER %I AFTER DELETE ON %I REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_delete_trigger_name
        , _table_name
        , __hive_triggerfunction_name_delete
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE TRIGGER %I AFTER UPDATE ON %I REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_update_trigger_name
        , _table_name
        , __hive_triggerfunction_name_update
        , __context_id
        , __shadow_table_name
    );

    EXECUTE format(
        'CREATE TRIGGER %I BEFORE TRUNCATE ON %I FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
        , __hive_truncate_trigger_name
        , _table_name
        , __hive_triggerfunction_name_truncate
        , __context_id
        , __shadow_table_name
    );

    INSERT INTO hive_triggers( registered_table_id, trigger_name, function_name )
    VALUES
         ( __registered_table_id, __hive_insert_trigger_name, __hive_triggerfunction_name_insert )
       , ( __registered_table_id, __hive_delete_trigger_name, __hive_triggerfunction_name_delete )
       , ( __registered_table_id, __hive_update_trigger_name, __hive_triggerfunction_name_update )
       , ( __registered_table_id, __hive_truncate_trigger_name, __hive_triggerfunction_name_truncate )
    ;
END;
$BODY$
;


