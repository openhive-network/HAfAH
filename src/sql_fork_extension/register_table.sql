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
    __context_id INTEGER := NULL;
    __registered_table_id INTEGER := NULL;
BEGIN
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I BIGSERIAL', _table_name, __hive_rowid_column_name );

    EXECUTE format('CREATE TABLE %I AS TABLE %I', __shadow_table_name, _table_name );
    EXECUTE format('DELETE FROM %I', __shadow_table_name ); --empty shadow table if origin table is not empty
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I SMALLINT NOT NULL', __shadow_table_name, __operation_column_name );

    INSERT INTO hive_registered_tables( context_id, origin_table_name, shadow_table_name )
    SELECT hc.id, tables.origin, tables.shadow
    FROM ( SELECT hc.id FROM hive_contexts hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( _table_name, __shadow_table_name  )  ) as tables( origin, shadow ) ON TRUE
    RETURNING context_id, id INTO __context_id, __registered_table_id
    ;

    ASSERT __context_id IS NOT NULL;
    ASSERT __registered_table_id IS NOT NULL;

    -- register insert trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT ON %I FOR EACH ROW EXECUTE PROCEDURE hive_on_table_trigger( %L )'
        , __hive_insert_trigger_name
        , _table_name
        , __context_id
    );

    -- register delete trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER DELETE ON %I FOR EACH ROW EXECUTE PROCEDURE hive_on_table_trigger( %L )'
        , __hive_delete_trigger_name
        , _table_name
        , __context_id
    );

    EXECUTE format(
            'CREATE TRIGGER %I AFTER UPDATE ON %I FOR EACH ROW EXECUTE PROCEDURE hive_on_table_trigger( %L )'
        , __hive_update_trigger_name
        , _table_name
        , __context_id
    );

    INSERT INTO hive_triggers( registered_table_id, name )
    VALUES
         ( __registered_table_id, __hive_insert_trigger_name )
       , ( __registered_table_id, __hive_delete_trigger_name )
       , ( __registered_table_id, __hive_update_trigger_name )
    ;
END;
$BODY$
;