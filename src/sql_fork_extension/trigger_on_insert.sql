DROP FUNCTION IF EXISTS hive_on_insert;
CREATE FUNCTION hive_on_insert()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __shadow_table_name TEXT;
BEGIN
    SELECT hrt.shadow_table_name
    FROM hive_registered_tables hrt
    WHERE hrt.origin_table_name = TG_TABLE_NAME
    INTO __shadow_table_name;

    ASSERT __shadow_table_name IS NOT NULL;
    ASSERT TG_NARGS = 1; --context id

    INSERT INTO __shadow_table_name
    SELECT  NEW.*, --inserted row
           ( SELECT current_block_num FROM hive_contexts WHERE id = TG_ARGV[ 0 ] ), --block num
           0 -- INSERT
    ;

    RETURN NEW;
END;
$BODY$