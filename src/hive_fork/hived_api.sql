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
END;
$BODY$
;