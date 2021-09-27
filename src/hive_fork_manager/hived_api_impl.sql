DROP TABLE IF EXISTS hive.indexes_constraints;
CREATE TABLE IF NOT EXISTS hive.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);

CREATE OR REPLACE FUNCTION hive.copy_blocks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    SELECT
          DISTINCT ON ( hbr.num ) hbr.num
        , hbr.hash
        , hbr.prev
        , hbr.created_at
    FROM
        hive.blocks_reversible hbr
    WHERE
        hbr.num <= _new_irreversible_block
    AND hbr.num > _head_block_of_irreversible_blocks
    ORDER BY hbr.num ASC, hbr.fork_id DESC;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_transactions_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.transactions
    SELECT
          htr.block_num
        , htr.trx_in_block
        , htr.trx_hash
        , htr.ref_block_num
        , htr.ref_block_prefix
        , htr.expiration
        , htr.signature
    FROM
        hive.transactions_reversible htr
    JOIN ( SELECT
              DISTINCT ON ( htr2.block_num ) htr2.block_num
            , htr2.fork_id
            FROM hive.transactions_reversible htr2
            WHERE
                htr2.block_num <= _new_irreversible_block
                AND htr2.block_num > _head_block_of_irreversible_blocks
            ORDER BY htr2.block_num ASC, htr2.fork_id DESC
    ) as num_and_forks ON htr.block_num = num_and_forks.block_num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_operations_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operations
    SELECT
           hor.id
         , hor.block_num
         , hor.trx_in_block
         , hor.op_pos
         , hor.op_type_id
         , hor.timestamp
         , hor.body
    FROM
        hive.operations_reversible hor
        JOIN ( SELECT
                     DISTINCT ON ( hor2.block_num ) hor2.block_num
                   , hor2.fork_id
               FROM hive.operations_reversible hor2
               WHERE
                   hor2.block_num <= _new_irreversible_block
               AND hor2.block_num > _head_block_of_irreversible_blocks
               ORDER BY hor2.block_num ASC, hor2.fork_id DESC
        ) as num_and_forks ON hor.block_num = num_and_forks.block_num AND hor.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_signatures_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.transactions_multisig
    SELECT
          tsr.trx_hash
        , tsr.signature
    FROM
        hive.transactions_multisig_reversible tsr
        JOIN hive.transactions_reversible htr ON htr.trx_hash = tsr.trx_hash AND htr.fork_id = tsr.fork_id
        JOIN (
            SELECT
                  DISTINCT ON ( htr2.block_num ) htr2.block_num
                , htr2.fork_id
            FROM hive.transactions_reversible htr2
            WHERE
               htr2.block_num <= _new_irreversible_block
            AND htr2.block_num > _head_block_of_irreversible_blocks
            ORDER BY htr2.block_num ASC, htr2.fork_id DESC
        ) as num_and_forks ON htr.block_num = num_and_forks.block_num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __lowest_contexts_irreversible_block INT;
BEGIN
    SELECT MIN( hac.irreversible_block )
    INTO __lowest_contexts_irreversible_block
    FROM hive.contexts hac;

    IF __lowest_contexts_irreversible_block IS NULL THEN
        __lowest_contexts_irreversible_block = _new_irreversible_block;
    END IF;

    DELETE FROM hive.operations_reversible hor
    WHERE hor.block_num < __lowest_contexts_irreversible_block;

    DELETE FROM hive.transactions_multisig_reversible htmr
    USING hive.transactions_reversible htr
    WHERE
            htr.fork_id = htmr.fork_id
        AND htr.trx_hash = htmr.trx_hash
        AND htr.block_num < __lowest_contexts_irreversible_block
    ;

    DELETE FROM hive.transactions_reversible htr
    WHERE htr.block_num < __lowest_contexts_irreversible_block;

    DELETE FROM hive.blocks_reversible hbr
    WHERE hbr.num < __lowest_contexts_irreversible_block;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_unecessary_events( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_events_id BIGINT := NULL;
    __max_block_num INTEGER := NULL;
BEGIN
    SELECT consistent_block INTO __max_block_num FROM hive.irreversible_data;

    -- find the upper bound of events possible to remove
    SELECT MIN(heq.id) INTO __upper_bound_events_id
    FROM hive.events_queue heq
    WHERE heq.event != 'BACK_FROM_FORK' AND heq.block_num = ( _new_irreversible_block + 1 ); --next block after irreversible

    DELETE FROM hive.events_queue heq
    USING ( SELECT MIN( hc.events_id) as id FROM hive.contexts hc ) as min_event
    WHERE ( heq.id < __upper_bound_events_id OR __upper_bound_events_id IS NULL )  AND ( heq.id < min_event.id OR min_event.id IS NULL ) AND heq.id != 0;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_constraints( in _table_name TEXT )
    RETURNS VOID
    AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    INSERT INTO hive.indexes_constraints( table_name, index_constraint_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        T.table_name,
        T.constraint_name,
        (
            CASE
                WHEN T.is_primary = TRUE THEN 'ALTER TABLE ' || T.table_name || ' ADD CONSTRAINT ' || T.constraint_name || ' PRIMARY KEY ( ' || array_to_string(array_agg( T.column_name::TEXT ), ', ') || ' ) '
                WHEN (T.is_unique = TRUE AND T.is_primary = FALSE ) THEN 'ALTER TABLE ' || T.table_name || ' ADD CONSTRAINT ' || T.constraint_name || ' UNIQUE ( ' || array_to_string(array_agg( T.column_name::TEXT ), ', ') || ' ) '
                WHEN (T.is_unique = FALSE AND T.is_primary = FALSE ) THEN 'CREATE INDEX IF NOT EXISTS ' || T.constraint_name || ' ON ' || T.table_name || ' ( ' || array_to_string(array_agg( T.column_name::TEXT ), ', ') || ' ) '
                END
            ),
        (T.is_unique = TRUE OR T.is_primary = TRUE ) is_constraint,
        (T.is_unique = FALSE AND T.is_primary = FALSE ) is_index,
        FALSE is_foreign_key
    FROM
        (
            SELECT
                _table_name table_name,
                i.relname constraint_name,
                a.attname column_name,
                ix.indisunique is_unique,
                ix.indisprimary is_primary,
                a.attnum
            FROM
                pg_class i,
                pg_index ix,
                pg_attribute a
            WHERE
                ( _table_name )::regclass::oid = ix.indrelid
              AND i.oid = ix.indexrelid
              AND a.attrelid =  ( _table_name )::regclass::oid
              AND a.attnum = ANY(ix.indkey)
            ORDER BY i.relname, a.attnum
        )T
    GROUP BY T.table_name, T.constraint_name, T.is_unique, T.is_primary
    ON CONFLICT DO NOTHING;

    --dropping indexes
    OPEN __cursor FOR ( SELECT ('DROP INDEX IF EXISTS '::TEXT || 'hive.' || index_constraint_name || ';') FROM hive.indexes_constraints WHERE table_name = _table_name AND is_index = TRUE );
      LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
      CLOSE __cursor;

    --dropping primary keys/unique contraints
    OPEN __cursor FOR ( SELECT ('ALTER TABLE '::TEXT || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';') FROM hive.indexes_constraints WHERE table_name = _table_name AND is_constraint = TRUE );
    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    INSERT INTO hive.indexes_constraints( table_name, index_constraint_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        _table_schema || '.' || _table_name,
        tc.constraint_name,
        'ALTER TABLE ' || _table_schema || '.' || _table_name || ' ADD CONSTRAINT ' || tc.constraint_name || ' FOREIGN KEY ( ' || kcu.column_name || ' ) REFERENCES ' || ccu.table_schema || '.' || ccu.table_name || ' ( ' || ccu.column_name || ' ) ',
        FALSE is_constraint,
        FALSE is_index,
        TRUE is_foreign_key
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = _table_name AND tc.table_schema = _table_schema
    ON CONFLICT DO NOTHING;

    OPEN __cursor FOR ( SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';') FROM hive.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE );

    LOOP
        FETCH __cursor INTO __command;
            EXIT WHEN NOT FOUND;
            EXECUTE __command;
    END LOOP;

    CLOSE __cursor;

END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_indexes_constraints( in _table_name TEXT )
    RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    --restoring indexes, primary keys, unique contraints
    OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE );
    LOOP
        FETCH __cursor INTO __command;
            EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    DELETE FROM hive.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = FALSE;

END;
$function$
LANGUAGE plpgsql VOLATILE
;


CREATE OR REPLACE FUNCTION hive.restore_foreign_keys( in _table_name TEXT )
    RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    --restoring indexes, primary keys, unique contraints
    OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = TRUE );
    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    DELETE FROM hive.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = TRUE;

END;
$function$
LANGUAGE plpgsql VOLATILE
;

