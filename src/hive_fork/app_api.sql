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

    EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_BLOCKS_VIEW;
        CREATE VIEW hive.%s_BLOCKS_VIEW
        AS
        SELECT
               hb.num
             , hb.hash
             , hb.prev
             , hb.created_at
        FROM hive.blocks hb
        JOIN hive.app_context hc ON  hb.num <= hc.irreversible_block AND hb.num <= hc.current_block_num
        WHERE hc.name = ''%s''
        UNION ALL
        SELECT
               reversible.num
             , reversible.hash
             , reversible.prev
             , reversible.created_at
        FROM
            (
            SELECT
            DISTINCT ON (hbr.num) num
               , hbr.hash
               , hbr.prev
               , hbr.created_at
               , hbr.fork_id
            FROM hive.blocks_reversible hbr
            JOIN hive.app_context hc ON  hbr.num > hc.irreversible_block AND hbr.fork_id <= hc.fork_id AND hbr.num <= hc.current_block_num
            WHERE hc.name = ''%s''
            ORDER BY hbr.num DESC, hbr.fork_id DESC
            ) as reversible
        ;', _name, _name, _name, _name
    );

END;
$BODY$
;