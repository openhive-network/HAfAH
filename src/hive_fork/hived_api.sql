CREATE OR REPLACE FUNCTION hive.back_from_fork( _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'BACK_FROM_FORK', _block_num_before_fork );
END;
$BODY$
;

--TODO: extend parameters for the block's data
CREATE OR REPLACE FUNCTION hive.push_block( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'NEW_BLOCK', _block_num );
END;
$BODY$
;

--TODO: extend parameters for the block's data
CREATE OR REPLACE FUNCTION hive.set_irreversible( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );
END;
$BODY$
;