CREATE OR REPLACE FUNCTION hive.app_create_context( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive_create_context( _name, hb.num )
    FROM hive.blocks hb
    ORDER BY hb.num DESC
    LIMIT 1;
END;
$BODY$
;