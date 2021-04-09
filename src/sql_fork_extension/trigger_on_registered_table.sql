DROP FUNCTION IF EXISTS hive_on_table_trigger;
CREATE FUNCTION hive_on_table_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := NULL;
    __block_num INTEGER := NULL;
    __values TEXT;
BEGIN
    SELECT hrt.shadow_table_name
    FROM hive_registered_tables hrt
    WHERE hrt.origin_table_name = TG_TABLE_NAME
    INTO __shadow_table_name;

    ASSERT TG_NARGS = 1; --context id

    SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

    ASSERT __shadow_table_name IS NOT NULL;
    ASSERT __block_num IS NOT NULL;

    IF ( __block_num < 0 ) THEN
        RAISE EXCEPTION 'Did not execute hive_context_next_block before table edition';
    END IF;

    IF ( TG_OP = 'INSERT' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 0'
            , __shadow_table_name
            , __block_num )
            USING NEW;
        RETURN NEW;
    END IF;

    IF ( TG_OP = 'DELETE' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 1'
            , __shadow_table_name
            , __block_num )
            USING OLD;
        RETURN NEW;
    END IF;

    IF ( TG_OP = 'UPDATE' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 2'
            , __shadow_table_name
            , __block_num )
            USING OLD;
        RETURN NEW;
    END IF;

    ASSERT FALSE, 'Unsuported trigger operation';
END;
$BODY$