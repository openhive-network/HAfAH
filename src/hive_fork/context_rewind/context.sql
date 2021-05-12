DROP FUNCTION IF EXISTS hive.create_context;
CREATE FUNCTION hive.create_context( _name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    --TODO: get irreversible = head block from irreversible_blocks table instead of -1
    INSERT INTO hive.context( name, current_block_num, irreversible_block, is_attached ) VALUES( _name, -1, -1, TRUE );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive.context_next_block;
CREATE FUNCTION hive.context_next_block( _name TEXT )
    RETURNS INTEGER
    LANGUAGE 'sql'
    VOLATILE
AS
$BODY$
    UPDATE hive.context
    SET current_block_num = current_block_num + 1
    WHERE name = _name
    RETURNING current_block_num
$BODY$
;
