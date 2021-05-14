DROP TYPE IF EXISTS hive.event_type CASCADE;
CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE' );

CREATE TABLE IF NOT EXISTS hive.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num INT NOT NULL
);

CREATE TABLE IF NOT EXISTS hive.app_context(
      events_id BIGINT NOT NULL
    , CONSTRAINT fk_hive_app_context FOREIGN KEY(events_id) REFERENCES hive.events_queue( id )
) INHERITS ( hive.context );