DROP TYPE IF EXISTS hive.event_type CASCADE;
CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE' );

CREATE TABLE IF NOT EXISTS hive.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num INT NOT NULL
);