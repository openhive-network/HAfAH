DROP TYPE IF EXISTS hive.event_type CASCADE;
CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE', 'MASSIVE_SYNC' );

-- field block_num has different meaning for each event type
-- BACK_FROM_FORK - last block before fork
-- NEW_BLOCK - new block num
-- NEW_IRREVERSIBLE - new irreversible block
-- MASSIVE_SYNC - head of irreversible block after massive push by hived
CREATE TABLE IF NOT EXISTS hive.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num INT NOT NULL
);