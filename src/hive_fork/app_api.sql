CREATE OR REPLACE FUNCTION hive.app_create_context( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.app_context(
           name
         , current_block_num
         , irreversible_block
         , is_attached
         , events_id)
     VALUES( _name, -1, -1, TRUE, NULL );
END;
$BODY$
;