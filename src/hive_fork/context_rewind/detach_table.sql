-- Whe a table is deteted their triggers are removed automatically
-- and there is no need to remove hive_rowid column
CREATE OR REPLACE FUNCTION hive.clean_after_uregister_table( _schema_name TEXT, _table_name TEXT )
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
    WHERE hrt.origin_table_schema = _schema_name AND  hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

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

    DELETE FROM hive.registered_tables hrt WHERE  hrt.origin_table_schema = _schema_name AND hrt.origin_table_name = _table_name;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.detach_table( _table_schema TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_name TEXT;
    __shadow_table_is_not_empty BOOL := FALSE;
BEGIN
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    WHERE  hrt.origin_table_schema = lower( _table_schema ) AND hrt.origin_table_name = _table_name INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
        RAISE EXCEPTION 'Table %.% is not registered', _table_schema, _table_name;
    END IF;

    EXECUTE format( 'SELECT EXISTS( SELECT * FROM hive.%I LIMIT 1 )', __shadow_table_name ) INTO __shadow_table_is_not_empty;

    IF __shadow_table_is_not_empty = TRUE THEN
        RAISE EXCEPTION 'Cannot detach a table %.%. Shadow table hive.% is not empty', _table_schema, _table_name, __shadow_table_name;
    END IF;

    FOR __trigger_name IN SELECT ht.trigger_name FROM hive.triggers ht WHERE ht.registered_table_id = __table_id
    LOOP
        EXECUTE format( 'ALTER TABLE %I.%I DISABLE TRIGGER %I', lower(_table_schema), _table_name, __trigger_name  );
    END LOOP;

    RETURN;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.detach_all( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INTEGER := NULL;
BEGIN
    SELECT ct.id FROM hive.context ct WHERE ct.name=_context INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Unknown context %', _context;
    END IF;

    PERFORM hive.detach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.context
    SET is_attached = FALSE
    WHERE id = __context_id;
END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.attach_table( _table_schema TEXT, _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __table_id INTEGER := NULL;
    __shadow_table_name TEXT;
    __trigger_name TEXT;
BEGIN
    SELECT hrt.id, hrt.shadow_table_name
    FROM hive.registered_tables hrt
    JOIN hive.context hc ON hc.id = hrt.context_id
    WHERE
          hrt.origin_table_schema = lower( _table_schema )
      AND hrt.origin_table_name = _table_name
      AND hc.is_attached = FALSE
    INTO __table_id, __shadow_table_name;

    IF __table_id IS NULL THEN
            RAISE EXCEPTION 'Table %.% is not registered or is already attached', _table_schema, _table_name;
    END IF;

    FOR __trigger_name IN SELECT ht.trigger_name FROM hive.triggers ht WHERE ht.registered_table_id = __table_id
        LOOP
        EXECUTE format( 'ALTER TABLE %I.%I ENABLE TRIGGER %I', lower(_table_schema), _table_name, __trigger_name  );
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.attach_all( _context TEXT, _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INTEGER := NULL;
    __current_block_num INTEGER := NULL;
BEGIN
    SELECT ct.id, ct.current_block_num
    FROM hive.context ct
    WHERE ct.name=_context AND ct.is_attached = FALSE
    INTO __context_id, __current_block_num;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Unknown context % or context is already attached', _context;
    END IF;

    IF __current_block_num > _last_synced_block THEN
        RAISE EXCEPTION 'Context % has already processed block nr %', _context, _last_synced_block;
    END IF;


    PERFORM hive.attach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.context
    SET
          current_block_num = _last_synced_block
        , is_attached = TRUE
    WHERE id = __context_id;
END;
$BODY$
;
