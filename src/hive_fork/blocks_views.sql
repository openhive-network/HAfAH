CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_BLOCKS_VIEW;
        CREATE VIEW hive.%s_BLOCKS_VIEW
        AS
        SELECT
               hb.num
             , hb.hash
             , hb.prev
             , hb.created_at
        FROM hive.blocks hb
        JOIN hive.app_context hc ON  hb.num <= hc.irreversible_block AND hb.num <= hc.current_block_num
        WHERE hc.name = ''%s''
        UNION ALL
        SELECT
               reversible.num
             , reversible.hash
             , reversible.prev
             , reversible.created_at
        FROM
            (
            SELECT
            DISTINCT ON (hbr.num) num
               , hbr.hash
               , hbr.prev
               , hbr.created_at
               , hbr.fork_id
            FROM hive.blocks_reversible hbr
            JOIN hive.app_context hc ON  hbr.num > hc.irreversible_block AND hbr.fork_id <= hc.fork_id AND hbr.num <= hc.current_block_num
            WHERE hc.name = ''%s''
            ORDER BY hbr.num DESC, hbr.fork_id DESC
            ) as reversible
        ;', _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_transactions_view;
        CREATE VIEW hive.%s_transactions_view AS
        SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
        FROM hive.transactions ht
        JOIN hive.app_context hc ON ht.block_num <= hc.irreversible_block AND ht.block_num <= hc.current_block_num
        WHERE hc.name = ''%s''
        UNION ALL
        SELECT reversible.block_num,
            reversible.trx_in_block,
            reversible.trx_hash,
            reversible.ref_block_num,
            reversible.ref_block_prefix,
            reversible.expiration,
            reversible.signature
        FROM ( SELECT
            htr.block_num,
            htr.trx_in_block,
            htr.trx_hash,
            htr.ref_block_num,
            htr.ref_block_prefix,
            htr.expiration,
            htr.signature,
            htr.fork_id
        FROM hive.transactions_reversible htr
        JOIN (
           SELECT DISTINCT ON (htr2.block_num) htr2.block_num
               , htr2.fork_id
           FROM hive.transactions_reversible htr2
           JOIN hive.app_context hc ON htr2.block_num > hc.irreversible_block AND htr2.fork_id <= hc.fork_id AND htr2.block_num <= hc.current_block_num
           WHERE hc.name = ''%s''
           ORDER BY htr2.block_num DESC, htr2.fork_id DESC
        ) as forks ON forks.fork_id = htr.fork_id AND forks.block_num = htr.block_num
     ) reversible;'
    , _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_OPERATIONS_VIEW;
        CREATE VIEW hive.%s_OPERATIONS_VIEW
        AS
        SELECT
              ho.id
            , ho.block_num
            , ho.trx_in_block
            , ho.op_pos
            , ho.op_type_id
            , ho.body
        FROM hive.operations ho
        JOIN hive.app_context hc ON  ho.block_num <= hc.irreversible_block AND ho.block_num <= hc.current_block_num
        WHERE hc.name = ''%s''
        UNION ALL
        SELECT
              reversible.id
            , reversible.block_num
            , reversible.trx_in_block
            , reversible.op_pos
            , reversible.op_type_id
            , reversible.body
        FROM
            (
            SELECT
                  hor.block_num
                , hor.id
                , hor.trx_in_block
                , hor.op_pos
                , hor.op_type_id
                , hor.body
            FROM hive.operations_reversible hor
            JOIN (
               SELECT DISTINCT ON (htr2.block_num) htr2.block_num
                   , htr2.fork_id
               FROM hive.transactions_reversible htr2
               JOIN hive.app_context hc ON htr2.block_num > hc.irreversible_block AND htr2.fork_id <= hc.fork_id AND htr2.block_num <= hc.current_block_num
               WHERE hc.name = ''%s''
               ORDER BY htr2.block_num DESC, htr2.fork_id DESC
                ) as forks ON forks.fork_id = hor.fork_id AND forks.block_num = hor.block_num
            ) as reversible
        ;', _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_TRANSACTIONS_MULTISIG_VIEW;
        CREATE VIEW hive.%s_TRANSACTIONS_MULTISIG_VIEW
        AS
        SELECT
              htm.trx_hash
            , htm.signature
        FROM hive.transactions_multisig htm
        JOIN hive.transactions ht ON ht.trx_hash = htm.trx_hash
        JOIN hive.app_context hc ON  ht.block_num <= hc.irreversible_block AND ht.block_num <= hc.current_block_num
        WHERE hc.name = ''%s''
        UNION ALL
        SELECT
              reversible.trx_hash
            , reversible.signature
        FROM
            (
            SELECT
            DISTINCT ON (htr.block_num) htr.block_num
                , htmr.trx_hash
                , htmr.signature
            FROM hive.transactions_multisig_reversible htmr
            JOIN hive.transactions_reversible htr ON htr.trx_hash = htmr.trx_hash AND htr.fork_id = htmr.fork_id
            JOIN (
                SELECT DISTINCT ON (htr2.block_num) htr2.block_num, htr2.fork_id
                FROM hive.transactions_reversible htr2
                JOIN hive.app_context hc ON htr2.block_num > hc.irreversible_block AND htr2.fork_id <= hc.fork_id AND htr2.block_num <= hc.current_block_num
                WHERE hc.name = ''%s''
                ORDER BY htr2.block_num DESC, htr2.fork_id DESC
            ) as forks ON forks.fork_id = htmr.fork_id AND forks.block_num = htr.block_num
            ) as reversible
        ;', _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;