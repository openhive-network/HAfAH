DROP FUNCTION IF EXISTS hive_register_table;
CREATE FUNCTION hive_register_table( _table_name TEXT, _context_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := 'hive_shadow_' || _table_name;
    __block_num_column_name TEXT := 'hive_block_num';
    __operation_column_name TEXT := 'hive_operation_type';
BEGIN
    EXECUTE format('CREATE TABLE %I AS TABLE %I', __shadow_table_name, _table_name );
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I INTEGER NOT NULL', __shadow_table_name, __block_num_column_name );
    EXECUTE format('ALTER TABLE %I ADD COLUMN %I SMALLINT NOT NULL', __shadow_table_name, __operation_column_name );

    INSERT INTO hive_registered_tables( context_id, origin_table_name, shadow_table_name )
    SELECT hc.id, tables.origin, tables.shadow
    FROM ( SELECT hc.id FROM hive_contexts hc WHERE hc.name =  _context_name ) as hc
    JOIN ( VALUES( _table_name, __shadow_table_name  )  ) as tables( origin, shadow ) ON TRUE
    ;
END;
$BODY$
;