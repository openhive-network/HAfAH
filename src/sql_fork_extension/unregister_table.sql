-- Whe a table is deteted their triggers are removet automatically
-- and there is no need to remove hive_rowid column
DROP FUNCTION IF EXISTS hive.unregister_table;
CREATE FUNCTION hive_clean_after_uregister_table( _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_funtion_name TEXT;
BEGIN
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    WHERE hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
        RAISE EXCEPTION 'Table is not registered';
    END IF;


    -- remove triggers functions
    FOR  __trigger_funtion_name IN SELECT ht.function_name FROM hive.triggers ht
    WHERE ht.registered_table_id = __table_id
    LOOP
       EXECUTE format( 'DROP FUNCTION %I', __trigger_funtion_name );
    END LOOP;

    -- remove informations about triggers
    DELETE FROM hive.triggers ht WHERE ht.registered_table_id = __table_id;

    --drop shadow table
    EXECUTE format( 'DROP TABLE hive.%I', __shadow_table_name );

    DELETE FROM hive.registered_tables hrt WHERE hrt.origin_table_name = _table_name;
END;
$BODY$
;


DROP FUNCTION IF EXISTS hive.unregister_table;
CREATE FUNCTION hive.unregister_table( _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_name TEXT;
    __trigger_funtion_name TEXT;
BEGIN
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    WHERE hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
            RAISE EXCEPTION 'Table is not registered';
    END IF;

    -- remove triggers
    FOR  __trigger_name IN SELECT ht.trigger_name FROM hive.triggers ht
    WHERE ht.registered_table_id = __table_id
    LOOP
        EXECUTE format( 'DROP TRIGGER %I ON hive.%I', __trigger_name, _table_name );
    END LOOP;

    PERFORM hive_clean_after_uregister_table( _table_name );

    EXECUTE format( 'ALTER TABLE hive.%I DROP COLUMN hive_rowid', _table_name );
    RETURN;
END;
$BODY$
;