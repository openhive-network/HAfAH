CREATE OR REPLACE FUNCTION hive.app_create_context( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Any context always starts with block before genesis, the app may detach the context and execute 'massive sync'
    -- after massive sync the application must attach its context to last already synced block
    INSERT INTO hive.app_context(
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

END;
$BODY$
;