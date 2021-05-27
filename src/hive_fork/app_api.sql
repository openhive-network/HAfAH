CREATE OR REPLACE FUNCTION hive.app_create_context( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- Any context always starts with block before genesis, the app may detach the context and execute 'massive sync'
    -- after massive sync the application must attach its context to last already synced block
    INSERT INTO hive.context(
           name
         , current_block_num
         , irreversible_block
         , is_attached
         , events_id
         , fork_id)
    SELECT cdata.name, cdata.block_num, COALESCE( hb.num, 0 ), cdata.is_attached, cdata.events_id, hf.id
    FROM
        ( VALUES ( _name, 0, TRUE, NULL::BIGINT ) ) as cdata( name, block_num, is_attached, events_id )
        JOIN ( SELECT hf.id FROM hive.fork hf ORDER BY id DESC LIMIT 1 ) as hf ON TRUE
        LEFT JOIN ( SELECT hb.num FROM hive.blocks hb ORDER BY hb.num DESC LIMIT 1 ) as hb ON TRUE
    ;

    PERFORM hive.create_blocks_view( _name );
    PERFORM hive.create_transactions_view( _name );
    PERFORM hive.create_operations_view( _name );
    PERFORM hive.create_signatures_view( _name );
END;
$BODY$
;

DROP TYPE IF EXISTS hive.blocks_range;
CREATE TYPE hive.blocks_range AS (
      first_block INT
    , last_block INT
);

CREATE OR REPLACE FUNCTION hive.app_next_block( _context_name TEXT )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INT;
    __context_is_attached BOOL;
    __current_block_num INT;
    __current_fork BIGINT;
    __current_event_id BIGINT;
    __next_event_id BIGINT;
    __next_event_type hive.event_type;
    __next_event_block_num INT;
    __next_block_to_process INT;
    __result hive.blocks_range;
BEGIN
    SELECT
          hac.current_block_num
        , hac.fork_id
        , hac.events_id
        , hac.id
        , hac.is_attached
    FROM hive.context hac
    WHERE hac.name = _context_name
    INTO __current_block_num, __current_fork, __current_event_id, __context_id, __context_is_attached;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context_name;
    END IF;

    IF __context_is_attached = FALSE THEN
        RAISE EXCEPTION 'Context % is detached', _context_name;
    END IF;

    -- no event was processed
    IF __current_event_id IS NULL THEN
        __current_event_id = 0;
    END IF;

    SELECT
          heq.event
        , heq.block_num
        , heq.id
    FROM hive.events_queue heq
    WHERE id > __current_event_id
    ORDER BY heq.id ASC
    LIMIT 1
    INTO __next_event_type,  __next_event_block_num, __next_event_id;

    CASE __next_event_type
        WHEN 'BACK_FROM_FORK' THEN
            PERFORM hive.context_back_from_fork( _context_name, __next_event_block_num );
            UPDATE hive.context
            SET
                  events_id = __next_event_id
                , current_block_num = __next_event_block_num
            WHERE id = __context_id;
            RETURN NULL;
        WHEN 'NEW_IRREVERSIBLE' THEN
            PERFORM hive.context_set_irreversible_block( _context_name, __next_event_block_num );
            UPDATE hive.context
            SET
                events_id = __next_event_id
              , current_block_num = __next_event_block_num
            WHERE id = __context_id;
            RETURN NULL;
        WHEN 'MASSIVE_SYNC' THEN
            --first we need to rewind all reversible changes
            PERFORM hive.context_back_from_fork( _context_name, hc.irreversible_block )
            FROM hive.context hc
            WHERE hc.id = __context_id;

            UPDATE hive.context
            SET   events_id = __next_event_id
                , current_block_num = current_block_num + 1
                , irreversible_block = __next_event_block_num
            WHERE id = __context_id;

            SELECT hc.current_block_num INTO __result.first_block
            FROM hive.context hc
            WHERE hc.id = __context_id;

            __result.last_block = __next_event_block_num;
            RETURN __result;
        WHEN 'NEW_BLOCK' THEN
            ASSERT  __next_event_block_num > __current_block_num, 'We could not process block without consume event';
            IF __next_event_block_num = ( __current_block_num + 1 ) THEN
                UPDATE hive.context
                SET   events_id = __next_event_id
                    , current_block_num = __next_event_block_num
                WHERE id = __context_id;
                __result.first_block = __next_event_block_num;
                __result.last_block = __next_event_block_num;
                RETURN __result ;
            END IF;
        ELSE
    END CASE;

    -- if there is no event or we still process irreversible blocks
    SELECT hb.num
    FROM hive.blocks hb
    WHERE hb.num > __current_block_num
    ORDER BY hb.num ASC LIMIT 1
    INTO __next_block_to_process;

    IF __next_block_to_process IS NULL THEN
        -- There is no new and expected block, needs to wait for a new block
        PERFORM pg_sleep( 1.5 );
        RETURN NULL;
    END IF;

    UPDATE hive.context
    SET current_block_num = __next_block_to_process
    WHERE id = __context_id;
    __result.first_block = __next_block_to_process;
    __result.last_block = __next_block_to_process;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_attach( _context TEXT, _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __head_of_irreversible_block INT:=0;
BEGIN
    SELECT hb.num INTO __head_of_irreversible_block
    FROM hive.blocks hb ORDER BY hb.num DESC LIMIT 1;

    IF _last_synced_block > __head_of_irreversible_block THEN
        RAISE EXCEPTION 'Cannot attach context % because the block num % is grater than top of irreversible block %'
            , _context, _last_synced_block,  __head_of_irreversible_block;
    END IF;

    PERFORM hive.context_attach( _context, _last_synced_block );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_context_detach( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_detach( _context );
END;
$BODY$
;