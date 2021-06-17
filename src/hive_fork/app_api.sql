CREATE OR REPLACE FUNCTION hive.app_create_context( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Any context always starts with block before genesis, the app may detach the context and execute 'massive sync'
    -- after massive sync the application must attach its context to last already synced block
    INSERT INTO hive.contexts(
           name
         , current_block_num
         , irreversible_block
         , is_attached
         , events_id
         , fork_id)
    SELECT cdata.name, cdata.block_num, COALESCE( hb.num, 0 ), cdata.is_attached, cdata.events_id, hf.id
    FROM
        ( VALUES ( _name, 0, TRUE, NULL::BIGINT ) ) as cdata( name, block_num, is_attached, events_id )
        JOIN ( SELECT hf.id FROM hive.fork hf ORDER BY id DESC LIMIT 1 ) as hf ON TRUE
        LEFT JOIN ( SELECT hb.num FROM hive.blocks hb ORDER BY hb.num DESC LIMIT 1 ) as hb ON TRUE
    ;

    PERFORM hive.create_blocks_view( _name );
    PERFORM hive.create_transactions_view( _name );
    PERFORM hive.create_operations_view( _name );
    PERFORM hive.create_signatures_view( _name );
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
    IF EXISTS( SELECT 1 FROM hive.registered_tables hrt JOIN hive.contexts hc ON hrt.context_id = hc.id WHERE hc.name = _context_name )
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