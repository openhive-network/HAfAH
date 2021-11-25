DROP VIEW IF EXISTS hive.account_operations_view;
CREATE VIEW hive.account_operations_view AS
SELECT
    t.account_id,
    t.account_op_seq_no,
    t.operation_id
FROM (
        SELECT
             ha.account_id,
             ha.account_op_seq_no,
             ha.operation_id
        FROM hive.account_operations ha
        JOIN hive.operations ho ON ho.id = ha.account_id
        UNION ALL
        SELECT
            reversible.account_id,
            reversible.account_op_seq_no,
            reversible.operation_id
        FROM ( SELECT
                har.account_id,
                har.account_op_seq_no,
                har.operation_id,
                har.fork_id
        FROM hive.account_operations_reversible har
        JOIN (
            SELECT hor.id, forks.max_fork_id
            FROM hive.operations_reversible hor
            JOIN (
                SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                FROM hive.blocks_reversible hbr
                WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
                GROUP by hbr.num
            ) as forks ON forks.max_fork_id = hor.fork_id AND forks.num = hor.block_num
        ) as arr ON arr.max_fork_id = har.fork_id AND arr.id = har.operation_id
     ) reversible
) t
;

DROP VIEW IF EXISTS hive.accounts_view;
CREATE VIEW hive.accounts_view AS
SELECT
    t.block_num,
    t.id,
    t.name
FROM
(
    SELECT
        ha.block_num,
        ha.id,
        ha.name
    FROM hive.accounts ha
    UNION ALL
    SELECT
        reversible.block_num,
        reversible.id,
        reversible.name
    FROM (
        SELECT
            har.block_num,
            har.id,
            har.name,
            har.fork_id
        FROM hive.accounts_reversible har
        JOIN (
            SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
            FROM hive.blocks_reversible hbr
            WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
            GROUP by hbr.num
        ) as forks ON forks.max_fork_id = har.fork_id AND forks.num = har.block_num
    ) reversible
) t
;

CREATE OR REPLACE VIEW hive.blocks_view
AS
SELECT t.num,
       t.hash,
       t.prev,
       t.created_at
FROM (
    SELECT hb.num,
        hb.hash,
        hb.prev,
        hb.created_at
    FROM hive.blocks hb
    UNION ALL
    SELECT hbr.num,
        hbr.hash,
        hbr.prev,
        hbr.created_at
    FROM hive.blocks_reversible hbr
    JOIN
    (
         SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
         FROM hive.blocks_reversible rb
         WHERE rb.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
         GROUP BY rb.num
    ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id
) t
;

CREATE OR REPLACE VIEW hive.transactions_view AS
SELECT
   t.block_num,
   t.trx_in_block,
   t.trx_hash,
   t.ref_block_num,
   t.ref_block_prefix,
   t.expiration,
   t.signature
FROM
(
    SELECT ht.block_num,
           ht.trx_in_block,
           ht.trx_hash,
           ht.ref_block_num,
           ht.ref_block_prefix,
           ht.expiration,
           ht.signature
    FROM hive.transactions ht
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
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
        GROUP by hbr.num
    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
    ) reversible
) t
;

CREATE OR REPLACE VIEW hive.operations_view
AS
SELECT t.id,
       t.block_num,
       t.trx_in_block,
       t.op_pos,
       t.op_type_id,
       t.timestamp,
       t.body
FROM
(
    SELECT
          ho.id,
          ho.block_num,
          ho.trx_in_block,
          ho.op_pos,
          ho.op_type_id,
          ho.timestamp,
          ho.body
    FROM hive.operations ho
    UNION ALL
      SELECT
        o.id,
        o.block_num,
        o.trx_in_block,
        o.op_pos,
        o.op_type_id,
        o.timestamp,
        o.body
      FROM hive.operations_reversible o
      -- Reversible operations view must show ops comming from newest fork (specific to app-context)
      -- and also hide ops present at earlier forks for given block
      JOIN
      (
        SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
        FROM hive.blocks_reversible hbr
        WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
        GROUP by hbr.num
      ) visible_ops on visible_ops.num = o.block_num and visible_ops.max_fork_id = o.fork_id
) t
;

CREATE VIEW hive.TRANSACTIONS_MULTISIG_VIEW
AS
SELECT
      t.trx_hash
    , t.signature
FROM (
    SELECT
          htm.trx_hash
        , htm.signature
    FROM hive.transactions_multisig htm
    JOIN hive.transactions ht ON ht.trx_hash = htm.trx_hash
    UNION ALL
    SELECT
           reversible.trx_hash
         , reversible.signature
    FROM (
        SELECT
               htmr.trx_hash
             , htmr.signature
        FROM hive.transactions_multisig_reversible htmr
        JOIN (
                SELECT htr.trx_hash, forks.max_fork_id
                FROM hive.transactions_reversible htr
                JOIN (
                    SELECT hbr.num, MAX(hbr.fork_id) as max_fork_id
                    FROM hive.blocks_reversible hbr
                    WHERE hbr.num > ( SELECT COALESCE( hid.consistent_block, 0 ) FROM hive.irreversible_data hid )
                    GROUP by hbr.num
                ) as forks ON forks.max_fork_id = htr.fork_id AND forks.num = htr.block_num
        ) as trr ON trr.trx_hash = htmr.trx_hash AND trr.max_fork_id = htmr.fork_id
    ) reversible
) t;