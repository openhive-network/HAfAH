DROP TYPE IF EXISTS hive.event_type CASCADE;
CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE' );

CREATE TABLE IF NOT EXISTS hive.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num INT NOT NULL
);

CREATE TABLE IF NOT EXISTS hive.fork(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL,
    time_of_fork TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_hive_fork PRIMARY KEY( id )
);

INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp )
ON CONFLICT DO NOTHING;

ALTER TABLE hive.context
ADD CONSTRAINT fk_hive_app_context FOREIGN KEY(events_id) REFERENCES hive.events_queue( id ),
ADD CONSTRAINT fk_2_hive_app_context FOREIGN KEY(fork_id) REFERENCES hive.fork( id );
