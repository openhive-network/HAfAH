-- hafah_backend.get_account_operations_count against a plain COUNT(*) with the
-- account_op_seq_no predicates, on steemit's history in the shared HAF (block
-- 5000000; account_op_seq_no 0..4265): every filtered whole-history,
-- wider-than-history and bounded range must give the same count.
-- Runs as haf_shared_consumer in the run's clone (.aidev/run-checks.sh install),
-- which may read the HAF tables but not write them, so it writes nothing.
\set ON_ERROR_STOP on

DO $$
DECLARE
  _steemit INT := (SELECT id FROM hive.accounts_view WHERE name = 'steemit');
  _case RECORD;
  _got BIGINT;
  _reference BIGINT;
BEGIN
  IF _steemit IS NULL THEN
    RAISE EXCEPTION 'account steemit is not in this database; the check needs the shared HAF at block 5000000';
  END IF;

  FOR _case IN
    SELECT * FROM (VALUES
      -- account,  ops,                  from_seq, to_seq, expected
      (_steemit,   ARRAY[2, 3, 4],              0,   4265,      394),
      (_steemit,   ARRAY[57],                   0,   4265,      834),
      (_steemit,   ARRAY[2],                    0,   4265,      299),
      (_steemit,   ARRAY[2, 51],              -10, 100000,      302),
      (_steemit,   ARRAY[999],                  0,   4265,        0),
      (_steemit,   ARRAY[2, 3, 4],              0,    999,        7),
      (_steemit,   ARRAY[2, 3, 4],           1000,   4265,      387),
      (_steemit,   ARRAY[57],                3000,   3999,      575),
      (_steemit,   ARRAY[57],                3500, 100000,      722),
      (_steemit,   ARRAY[2],                 2000,   2999,      253),
      (_steemit,   ARRAY[2, 57],             2500,   3500,      260),
      (_steemit,   ARRAY[0],                 4265,   4265,        1),
      -- The Denser wallet's operation-types filter.
      (_steemit,   ARRAY[2, 3, 4, 55, 54, 32, 33, 27, 34, 31, 28, 29, 50, 57, 39, 51, 49, 8],
                                                0,   4265,     1235),
      (-1,         ARRAY[2],                    0,    100,        0),
      (_steemit,   ARRAY[2],                 NULL,   NULL,        0)
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

  _got := hafah_backend.get_account_operations_count(NULL, _steemit, 3, 4265);
  IF _got <> 4263 THEN
    RAISE EXCEPTION 'unfiltered get_account_operations_count(NULL, steemit, 3, 4265) = %, expected 4263', _got;
  END IF;

  RAISE NOTICE 'get_account_operations_count matches the seq-predicate count in every case';
END
$$;
