-- hafah_backend.get_account_operations_count against a plain COUNT(*) with the
-- account_op_seq_no predicates, on a fabricated account history: every filtered
-- whole-history, wider-than-history and bounded range must give the same count.
-- Runs as haf_admin (.aidev/run-checks.sh install) and rolls everything back.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO hafd.accounts (id, name) VALUES
  (2000000001, 'aidev-count-a'),
  (2000000002, 'aidev-count-b');

-- Account a: seq 1..30, op types cycling 2, 3, 4, 2, 3, 4, ... except seq 11..15
-- which are type 50. Account b: seq 5..9, all type 2 (a history not starting at 0/1).
INSERT INTO hafd.operations (id, trx_in_block, op_type_id, op_pos)
SELECT 9000000000000 + g, 0, 0, g FROM generate_series(1, 35) g;

INSERT INTO hafd.account_operations (account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id)
SELECT 2000000001, 2000000001, g, 9000000000000 + g,
       CASE WHEN g BETWEEN 11 AND 15 THEN 50 ELSE 2 + (g - 1) % 3 END
FROM generate_series(1, 30) g
UNION ALL
SELECT 2000000002, 2000000002, g, 9000000000000 + 30 + g - 4, 2
FROM generate_series(5, 9) g;

DO $$
DECLARE
  _case RECORD;
  _got BIGINT;
  _reference BIGINT;
BEGIN
  FOR _case IN
    SELECT * FROM (VALUES
      -- account,  ops,                  from_seq, to_seq, expected
      (2000000001, ARRAY[2, 3, 4],              1,     30,       25),
      (2000000001, ARRAY[50],                   1,     30,        5),
      (2000000001, ARRAY[2],                    1,     30,        9),
      (2000000001, ARRAY[2, 50],              -10,    100,       14),
      (2000000001, ARRAY[99],                   1,     30,        0),
      (2000000001, ARRAY[2, 3, 4],              2,     30,       24),
      (2000000001, ARRAY[2, 3, 4],              1,     29,       24),
      (2000000001, ARRAY[50],                  12,     14,        3),
      (2000000001, ARRAY[2],                   16,    100,        5),
      (2000000002, ARRAY[2],                    5,      9,        5),
      (2000000002, ARRAY[2],                    6,      9,        4),
      (2000000002, ARRAY[2],                    0,      8,        4),
      (2000000003, ARRAY[2],                    1,     30,        0),
      (2000000001, ARRAY[2],                 NULL,   NULL,        0)
    ) AS c (account_id, ops, from_seq, to_seq, expected)
  LOOP
    _got := hafah_backend.get_account_operations_count(_case.ops, _case.account_id, _case.from_seq, _case.to_seq);
    _reference := (
      SELECT COUNT(*)
      FROM hive.account_operations_view aov
      WHERE aov.account_id = _case.account_id
        AND aov.op_type_id = ANY(_case.ops)
        AND aov.account_op_seq_no >= _case.from_seq
        AND aov.account_op_seq_no <= _case.to_seq
    );
    IF _got IS DISTINCT FROM _reference OR _got IS DISTINCT FROM _case.expected THEN
      RAISE EXCEPTION 'get_account_operations_count(%, %, %, %) = %, seq-predicate count %, expected %',
        _case.ops, _case.account_id, _case.from_seq, _case.to_seq, _got, _reference, _case.expected;
    END IF;
  END LOOP;

  _got := hafah_backend.get_account_operations_count(NULL, 2000000001, 3, 30);
  IF _got <> 28 THEN
    RAISE EXCEPTION 'unfiltered get_account_operations_count(NULL, 2000000001, 3, 30) = %, expected 28', _got;
  END IF;

  RAISE NOTICE 'get_account_operations_count matches the seq-predicate count in every case';
END
$$;

ROLLBACK;
