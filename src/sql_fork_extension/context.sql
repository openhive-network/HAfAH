DROP FUNCTION IF EXISTS hive_create_context;
CREATE FUNCTION hive_create_context( _name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive_contexts( name ) VALUES( _name );
END;
$BODY$
;