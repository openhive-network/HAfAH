CREATE OR REPLACE FUNCTION hive.squash_events( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __next_fork_event_id BIGINT;
    __next_fork_block_num INT;
    __context_current_block_num INT;
    __context_id hive.context.id%TYPE;
BEGIN
    -- first find a newer fork nearest current block
    SELECT heq.id, heq.block_num, hc.current_block_num, hc.id INTO __next_fork_event_id, __next_fork_block_num, __context_current_block_num, __context_id
    FROM hive.events_queue heq
    JOIN hive.context hc ON hc.events_id < heq.id AND hc.current_block_num <= heq.block_num
    WHERE heq.event = 'BACK_FROM_FORK' AND hc.name = _context
    ORDER BY heq.block_num ASC, heq.id DESC
    LIMIT 1;

    -- no newer fork, nothing to do
    IF __next_fork_event_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE hive.context
    SET events_id = __next_fork_event_id - 1 -- -1 because we pretend that we stay just before the next fork
    WHERE id = __context_id;
END;
$BODY$
;