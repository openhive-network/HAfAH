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
    __lowest_contexts_fork BIGINT;
    __lowest_contexts_block_on_fork INT;
    __current_fork BIGINT;
BEGIN
    SELECT hf.id INTO __current_fork
    FROM hive.fork hf
    ORDER BY hf.id DESC
    LIMIT 1;

    ASSERT __current_fork IS NOT NULL;

    SELECT
          COALESCE( hac.fork_id, 0 )
        , COALESCE( hac.current_block_num, 0 )
    INTO __lowest_contexts_fork, __lowest_contexts_block_on_fork
    FROM hive.app_context hac
    ORDER BY hac.fork_id ASC, hac.current_block_num ASC
    LIMIT 1;

    IF __lowest_contexts_fork IS NULL OR __lowest_contexts_block_on_fork IS NULL THEN
        __lowest_contexts_fork = __current_fork;
        __lowest_contexts_block_on_fork = _new_irreversible_block;
    END IF;

    RAISE NOTICE 'current fork: %, lowest fork: %, lowest block: %', __current_fork, __lowest_contexts_fork, __lowest_contexts_block_on_fork;

    DELETE FROM hive.operations_reversible hor
    WHERE
           hor.fork_id < __lowest_contexts_fork
        OR ( hor.fork_id = __lowest_contexts_fork AND hor.block_num < __lowest_contexts_block_on_fork );

    DELETE
    FROM hive.transactions_multisig_reversible htmr
    USING hive.transactions_reversible htr
    WHERE
        ( htr.fork_id = htmr.fork_id AND htr.trx_hash = htmr.trx_hash )
        AND (
            htmr.fork_id < __lowest_contexts_fork
            OR ( htmr.fork_id = __lowest_contexts_fork AND htr.block_num < __lowest_contexts_block_on_fork )
        )
    ;

    DELETE FROM hive.transactions_reversible htr
    WHERE
          htr.fork_id < __lowest_contexts_fork
       OR ( htr.fork_id = __lowest_contexts_fork AND htr.block_num < __lowest_contexts_block_on_fork );

    DELETE FROM hive.blocks_reversible hbr
    WHERE
               hbr.fork_id < __lowest_contexts_fork
            OR ( hbr.fork_id = __lowest_contexts_fork AND hbr.num < __lowest_contexts_block_on_fork );
END;
$BODY$
;


