CREATE OR REPLACE FUNCTION hive.squash_fork_events( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __next_fork_event_id BIGINT;
    __next_fork_block_num INT;
    __context_current_block_num INT;
    __context_id hive.contexts.id%TYPE;
    __cannot_jump BOOL:= TRUE;
BEGIN
    -- first find a newer fork nearest current block
    SELECT heq.id, heq.block_num, hc.current_block_num, hc.id INTO __next_fork_event_id, __next_fork_block_num, __context_current_block_num, __context_id
    FROM hive.events_queue heq
    JOIN hive.fork hf ON hf.id = heq.block_num
    JOIN hive.contexts hc ON hc.events_id < heq.id AND hc.current_block_num >= hf.block_num
    WHERE heq.event = 'BACK_FROM_FORK' AND hc.name = _context
    ORDER BY hf.block_num ASC, heq.id DESC
    LIMIT 1;

    -- no newer fork, nothing to do
    IF __next_fork_event_id IS NULL THEN
        RETURN;
    END IF;

    -- there may be NEW_IRREVERSIBLE or MASSIVE_SYNC in the range
    SELECT EXISTS (
        SELECT 1
        FROM hive.events_queue heq
        JOIN hive.contexts hc ON heq.id < __next_fork_event_id AND heq.id > hc.events_id
        WHERE ( heq.event = 'NEW_IRREVERSIBLE' OR heq.event = 'MASSIVE_SYNC' ) AND hc.name = _context
    )
    INTO __cannot_jump;

    IF __cannot_jump THEN
        RETURN;
    END IF;

    UPDATE hive.contexts
    SET events_id = __next_fork_event_id - 1 -- -1 because we pretend that we stay just before the next fork
    WHERE id = __context_id;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.squash_end_massive_sync_events( _context TEXT )
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __next_massive_sync_event_id BIGINT;
    __context_current_block_num INT;
    __context_id hive.contexts.id%TYPE;
    __irreversible_block_num INT;
BEGIN
    -- first find a newer massive_sync nearest current block
    SELECT heq.id, hc.current_block_num, hc.id, hc.irreversible_block
    INTO __next_massive_sync_event_id, __context_current_block_num, __context_id, __irreversible_block_num
    FROM hive.events_queue heq
    JOIN hive.contexts hc ON COALESCE( hc.events_id, 1 ) < heq.id -- 1 because we don't want squash only the first event
    WHERE heq.event = 'MASSIVE_SYNC' AND hc.name = _context
    ORDER BY heq.id DESC
    LIMIT 1;

    SELECT hc.current_block_num
    INTO __context_current_block_num
    FROM hive.contexts hc
    WHERE hc.name = _context
    ;

    -- no newer MASSIVE_SYNC, nothing to do
    IF __next_massive_sync_event_id IS NULL THEN
            RETURN FALSE;
    END IF;

    -- back form fork is required
    PERFORM hive.context_back_from_fork( _context, __irreversible_block_num );

    UPDATE hive.contexts
    SET events_id = __next_massive_sync_event_id - 1 -- -1 because we pretend that we stay just before the next MASSIVE_SYNC_EVENT
    WHERE id = __context_id;
    RETURN TRUE;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.squash_events( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    IF NOT hive.squash_end_massive_sync_events( _context ) THEN
        PERFORM hive.squash_fork_events( _context );
    END IF;
END;
$BODY$
;

DROP TYPE IF EXISTS hive.blocks_range;
CREATE TYPE hive.blocks_range AS (
    first_block INT
    , last_block INT
    );

CREATE OR REPLACE FUNCTION hive.app_next_block_forking_app( _context_name TEXT )
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
    __irreversible_block_num INT;
    __next_event_id BIGINT;
    __next_event_type hive.event_type;
    __next_event_block_num INT;
    __next_block_to_process INT;
    __last_block_to_process INT;
    __fork_id BIGINT;
    __result hive.blocks_range;
BEGIN
    PERFORM hive.squash_events( _context_name );

    SELECT
        hac.current_block_num
         , hac.fork_id
         , hac.events_id
         , hac.id
         , hac.is_attached
         , hac.irreversible_block
    FROM hive.contexts hac
    WHERE hac.name = _context_name
    INTO __current_block_num, __current_fork, __current_event_id, __context_id, __context_is_attached, __irreversible_block_num;

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
        SELECT hf.id, hf.block_num INTO __fork_id, __next_event_block_num
        FROM hive.fork hf
        WHERE hf.id = __next_event_block_num; -- block_num for BFF events = fork_id

        PERFORM hive.context_back_from_fork( _context_name, __next_event_block_num );

        UPDATE hive.contexts
        SET
            events_id = __next_event_id
          , current_block_num = __next_event_block_num
          , fork_id = __fork_id
        WHERE id = __context_id;
        RETURN NULL;
    WHEN 'NEW_IRREVERSIBLE' THEN
        PERFORM hive.context_set_irreversible_block( _context_name, __next_event_block_num );
        UPDATE hive.contexts
        SET
            events_id = __next_event_id
        WHERE id = __context_id;
        -- no RETURN here because code after the case will continue processing irreversible blocks only
    WHEN 'MASSIVE_SYNC' THEN
        --massive events are squashe at the function begin
        UPDATE hive.contexts
        SET   events_id = __next_event_id
            , irreversible_block = __next_event_block_num
        WHERE id = __context_id;
        -- no RETURN here because code after the case will continue processing irreversible blocks only
    WHEN 'NEW_BLOCK' THEN
        ASSERT  __next_event_block_num > __current_block_num, 'We could not process block without consume event';
        IF __next_event_block_num = ( __current_block_num + 1 ) THEN
            UPDATE hive.contexts
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
    SELECT hc.irreversible_block INTO __irreversible_block_num
    FROM hive.contexts hc WHERE hc.id = __context_id;

    SELECT MIN( hb.num ), MAX( hb.num )
    FROM hive.blocks hb
    WHERE hb.num > __current_block_num AND hb.num <= __irreversible_block_num
    INTO __next_block_to_process, __last_block_to_process;

    IF __next_block_to_process IS NULL THEN
            -- There is no new and expected block, needs to wait for a new block
            PERFORM pg_sleep( 1.5 );
    RETURN NULL;
    END IF;

    UPDATE hive.contexts
    SET current_block_num = __next_block_to_process
    WHERE id = __context_id;
    __result.first_block = __next_block_to_process;
    __result.last_block = __last_block_to_process;
    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_next_block_non_forking_app( _context_name TEXT )
    RETURNS hive.blocks_range
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INT;
    __context_is_attached BOOL;
    __current_block_num INT;
    __irreversible_block_num INT;
    __current_fork BIGINT;
    __current_event_id BIGINT;
    __next_event_id BIGINT;
    __next_event_type hive.event_type;
    __next_event_block_num INT;
    __next_block_to_process INT;
    __last_block_to_process INT;
    __fork_id BIGINT;
    __max_events_id BIGINT;
    __result hive.blocks_range;
BEGIN
    PERFORM hive.squash_events( _context_name );

    SELECT
           hac.current_block_num
         , hac.fork_id
         , hac.events_id
         , hac.id
         , hac.is_attached
         , hac.irreversible_block
    FROM hive.contexts hac
    WHERE hac.name = _context_name
    INTO __current_block_num, __current_fork, __current_event_id, __context_id, __context_is_attached, __irreversible_block_num;

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

    IF __next_event_id IS NOT NULL THEN
        UPDATE hive.contexts
        SET events_id = __next_event_id
        WHERE id = __context_id;
    END IF;

    CASE __next_event_type
        WHEN 'NEW_IRREVERSIBLE' THEN
            IF __next_event_block_num > __irreversible_block_num THEN
                PERFORM hive.context_set_irreversible_block( _context_name, __next_event_block_num );
            END IF;
        WHEN 'MASSIVE_SYNC' THEN
            IF __next_event_block_num > __irreversible_block_num THEN
                PERFORM hive.context_set_irreversible_block( _context_name, __next_event_block_num );
            END IF;
        ELSE
    END CASE;

    SELECT hc.irreversible_block INTO __irreversible_block_num
    FROM hive.contexts hc WHERE hc.id = __context_id;

    -- if there is no event or we still process irreversible blocks
    SELECT MIN( hb.num ), MAX( hb.num )
    FROM hive.blocks hb
    WHERE hb.num > __current_block_num AND hb.num <= __irreversible_block_num
    INTO __next_block_to_process, __last_block_to_process;

    IF __next_block_to_process IS NULL THEN
        -- There is no new and expected block, needs to wait for a new block
        SELECT MAX( heq.id ) INTO __max_events_id FROM hive.events_queue heq;
        IF __max_events_id <= __next_event_id THEN
            PERFORM pg_sleep( 1.5 );
        END IF;
        RETURN NULL;
    END IF;

    UPDATE hive.contexts
    SET current_block_num = __next_block_to_process
    WHERE id = __context_id;

    __result.first_block = __next_block_to_process;
    __result.last_block = __last_block_to_process;
    RETURN __result;
    END;
$BODY$
;
