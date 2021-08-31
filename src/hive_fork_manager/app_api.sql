CREATE OR REPLACE FUNCTION hive.app_create_context( _name hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Any context always starts with block before genesis, the app may detach the context and execute 'massive sync'
    -- after massive sync the application must attach its context to last already synced block
    PERFORM hive.context_create(
        _name
        , ( SELECT MAX( hf.id ) FROM hive.fork hf ) -- current fork id
        , COALESCE( ( SELECT hid.consistent_block FROM hive.irreversible_data hid ), 0 ) -- head of irreversible block
    );

    PERFORM hive.create_blocks_view( _name );
    PERFORM hive.create_transactions_view( _name );
    PERFORM hive.create_operations_view( _name );
    PERFORM hive.create_signatures_view( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_remove_context( _name hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_remove( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_exists( _name TEXT )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN hive.context_exists( _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_is_forking( _context_name TEXT )
    RETURNS BOOL
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __result BOOL;
BEGIN
    SELECT  hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context_name
    INTO __context_id;

    IF __context_id IS NULL THEN
                RAISE EXCEPTION 'No context with name %', _context_name;
    END IF;

    -- if there there is a registered table for a given context
    SELECT EXISTS( SELECT 1 FROM hive.registered_tables hrt WHERE hrt.context_id = __context_id ) INTO __result;
    RETURN __result;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.app_next_block( _context_name TEXT )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result hive.blocks_range;
BEGIN
    -- if there ther is  registered table for given context
    IF hive.app_is_forking( _context_name )
    THEN
        RETURN hive.app_next_block_forking_app( _context_name );
    END IF;

    RETURN hive.app_next_block_non_forking_app( _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_attach( _context TEXT, _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __head_of_irreversible_block INT:=0;
BEGIN
    SELECT hb.num INTO __head_of_irreversible_block
    FROM hive.blocks hb ORDER BY hb.num DESC LIMIT 1;

    IF _last_synced_block > __head_of_irreversible_block THEN
        RAISE EXCEPTION 'Cannot attach context % because the block num % is grater than top of irreversible block %'
            , _context, _last_synced_block,  __head_of_irreversible_block;
    END IF;

    PERFORM hive.context_attach( _context, _last_synced_block );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_detach( _context );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_register_table( _table_schema TEXT,  _table_name TEXT,  _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'ALTER TABLE %I.%s ADD COLUMN hive_rowid BIGINT NOT NULL DEFAULT 0', _table_schema, _table_name );
    EXECUTE format( 'ALTER TABLE %I.%s INHERIT hive.%s', _table_schema, _table_name, _context );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_unregister_table( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.unregister_table( _table_schema, _table_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_get_irreversible_block( _context_name TEXT )
    RETURNS hive.contexts.irreversible_block%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hive.contexts.irreversible_block%TYPE;
BEGIN
    IF hive.app_is_forking( _context_name )
    THEN
        SELECT hc.irreversible_block INTO __result
        FROM hive.contexts hc
        WHERE hc.name = _context_name;
    ELSE
        SELECT COALESCE( MAX( hb.num ), 0 ) INTO __result FROM hive.blocks hb;
    END IF;

    RETURN __result;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.app_context_is_attached( _context_name TEXT )
    RETURNS bool
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result bool;
BEGIN
    SELECT hc.is_attached INTO __result
    FROM hive.contexts hc
    WHERE hc.name = _context_name;

    IF __result IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context_name;
    END IF;

    RETURN __result;
END;
$BODY$;