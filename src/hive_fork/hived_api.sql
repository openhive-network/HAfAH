CREATE OR REPLACE FUNCTION hive.back_from_fork( _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'BACK_FROM_FORK', _block_num_before_fork );
    INSERT INTO hive.fork(block_num, time_of_fork)
        VALUES( _block_num_before_fork, LOCALTIMESTAMP );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.push_block(
      _block hive.blocks
    , _transactions hive.transactions[]
    , _signatures hive.transactions_multisig[]
    , _operations hive.operations[]
)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __fork_id hive.fork.id%TYPE;
BEGIN
    SELECT hf.id
    INTO __fork_id
    FROM hive.fork hf ORDER BY hf.id DESC LIMIT 1;

    INSERT INTO hive.events_queue( event, block_num )
        VALUES( 'NEW_BLOCK', _block.num );

    INSERT INTO hive.blocks_reversible VALUES( _block.*, __fork_id );
    INSERT INTO hive.transactions_reversible VALUES( ( unnest( _transactions ) ).*, __fork_id );
    INSERT INTO hive.transactions_multisig_reversible VALUES( ( unnest( _signatures ) ).*, __fork_id );
    INSERT INTO hive.operations_reversible VALUES( ( unnest( _operations ) ).*, __fork_id );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.set_irreversible( _block_num INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __irreversible_head_block hive.blocks.num%TYPE;
BEGIN
    -- application contexts will use the event to clear data in shadow tables
    INSERT INTO hive.events_queue( event, block_num )
    VALUES( 'NEW_IRREVERSIBLE', _block_num );

    -- copy to irreversible
    PERFORM hive.copy_blocks_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_transactions_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_operations_to_irreversible( __irreversible_head_block, _block_num );
    PERFORM hive.copy_signatures_to_irreversible( __irreversible_head_block, _block_num );

    -- remove unneeded blocks
    PERFORM hive.remove_obsolete_reversible_data( _block_num );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.end_massive_sync()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.events_queue( event, block_num )
    SELECT event_type.event, irreversible.num
    FROM
         ( VALUES ( 'MASSIVE_SYNC'::hive.event_type ) ) as event_type( event )
    JOIN ( SELECT hib.num FROM hive.blocks hib ORDER BY hib.num DESC LIMIT 1 ) as irreversible ON irreversible.num IS NOT NULL;
END;
$BODY$
;