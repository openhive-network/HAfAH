CREATE OR REPLACE FUNCTION hive.remove_obsolete_operations( _shadow_table_name TEXT, _irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    EXECUTE format(
          'DELETE FROM hive.%I st WHERE st.hive_block_num <= %s'
        , _shadow_table_name
        , _irreversible_block
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible_block( _block_num INTEGER )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __current_irreversible INTEGER;
BEGIN
    -- validate new irreversible
    SELECT irreversible_block FROM hive.control_status INTO __current_irreversible;

    IF _block_num < __current_irreversible THEN
        RAISE EXCEPTION 'The proposed block number of irreversible block is lower than the current one';
    END IF;

    UPDATE hive.control_status  SET irreversible_block = _block_num;

    PERFORM
        hive.remove_obsolete_operations( hrt.shadow_table_name, _block_num )
    FROM hive.registered_tables hrt ORDER BY hrt.id;
END;
$BODY$
;