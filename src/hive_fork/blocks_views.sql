CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
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
        ;', _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;