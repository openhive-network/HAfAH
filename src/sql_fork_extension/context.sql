DROP FUNCTION IF EXISTS hive.create_context;
CREATE FUNCTION hive.create_context( _name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.context( name, current_block_num ) VALUES( _name, -1 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive_context_next_block;
CREATE FUNCTION hive_context_next_block( _name TEXT )
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

--TODO: remove context ?