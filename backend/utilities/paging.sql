SET ROLE hafah_owner;

/*
 * paging.sql: Pagination helper functions.
 *
 * Types:
 *   - hafah_backend.calculate_pages_return - Return type for calculate_pages
 *   - hafah_backend.account_filter_return - Return type for account_range
 *   - hafah_backend.account_op_match - Element type for account_rare_op_matches
 *
 * Functions:
 *   - hafah_backend.calculate_pages() - Calculate pagination parameters
 *   - hafah_backend.account_range() - Calculate account operation range
 *   - hafah_backend.total_pages() - Calculate total pages for given count
 *   - hafah_backend.get_account_operations_count() - Count operations for account
 *   - hafah_backend.account_rare_match_threshold() - Break-even of the filtered page plans
 *   - hafah_backend.account_op_types_are_rare() - Choose the filtered page plan
 *   - hafah_backend.account_rare_op_matches() - Choose the include page plan, keeping rare matches
 */

-- ===================================================================================
-- TYPES
-- ===================================================================================

DROP TYPE IF EXISTS hafah_backend.calculate_pages_return CASCADE;
CREATE TYPE hafah_backend.calculate_pages_return AS (
    rest_of_division    INT,
    total_pages         INT,
    page_num            INT,
    offset_filter       INT,
    limit_filter        INT
);

DROP TYPE IF EXISTS hafah_backend.account_filter_return CASCADE;
CREATE TYPE hafah_backend.account_filter_return AS (
    from_block    INT,
    to_block      INT,
    from_seq      INT,
    to_seq        INT
);

DROP TYPE IF EXISTS hafah_backend.account_op_match CASCADE;
CREATE TYPE hafah_backend.account_op_match AS (
    operation_id         BIGINT,
    op_type_id           SMALLINT,
    account_op_seq_no    INT
);

-- ===================================================================================
-- FUNCTIONS
-- ===================================================================================

/*
 * ===================================================================================
 * calculate_pages
 * ===================================================================================
 * PURPOSE: Calculates pagination parameters including offset and limit based on
 *          total count, requested page, sort direction, and page size.
 *
 * PARAMETERS:
 *   _count    - Total number of items
 *   _page     - Requested page number (NULL for first page)
 *   _order_is - Sort direction ('asc' or 'desc')
 *   _limit    - Items per page
 *
 * RETURNS: hafah_backend.calculate_pages_return - pagination parameters
 */
CREATE OR REPLACE FUNCTION hafah_backend.calculate_pages(
    _count       INT,
    _page        INT,
    _order_is    hafah_backend.sort_direction, -- noqa: LT01, CP05
    _limit       INT
)
RETURNS hafah_backend.calculate_pages_return -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS $$
DECLARE
  __rest_of_division INT;
  __total_pages INT;
  __page INT;
  __offset INT;
  __limit INT;
BEGIN
  __rest_of_division := (_count % _limit)::INT;

  __total_pages := (
    CASE
      WHEN (__rest_of_division = 0) THEN
        _count / _limit
      ELSE
        (_count / _limit) + 1
    END
  )::INT;

  __page := (
    CASE
      WHEN (_page IS NULL) THEN
        1
      WHEN (_page IS NOT NULL) AND _order_is = 'desc' THEN
        __total_pages - _page + 1
      ELSE
        _page
    END
  );

  __offset := (
    CASE
      WHEN _order_is = 'desc' AND __page != 1 AND __rest_of_division != 0 THEN
        ((__page - 2) * _limit) + __rest_of_division
      WHEN __page = 1 THEN
        0
      ELSE
        (__page - 1) * _limit
    END
  );

  __limit := (
    CASE
      WHEN _order_is = 'desc' AND __page = 1 AND __rest_of_division != 0 THEN
        __rest_of_division
      WHEN _order_is = 'asc' AND __page = __total_pages AND __rest_of_division != 0 THEN
        __rest_of_division
      ELSE
        _limit
    END
  );

  PERFORM hafah_backend.validate_page(_page, __total_pages);

  RETURN (__rest_of_division, __total_pages, __page, __offset, __limit)::hafah_backend.calculate_pages_return;
END
$$;

/*
 * ===================================================================================
 * account_range
 * ===================================================================================
 * PURPOSE: Calculates block and sequence number ranges for account operations.
 *          Both bounds walk hive_account_operations_uq1 (account_id,
 *          account_op_seq_no) and stop at the first operation inside the block
 *          range. A block bound is an operation_id bound: every operation of
 *          block N has an id in [operation_id(N, 0), operation_id(N + 1, 0)).
 *
 *          HAfAH serves irreversible data only: the upper bound never exceeds
 *          hive.app_get_irreversible_block(), so every account history variant
 *          paging inside [from_seq, to_seq] reads irreversible operations only.
 *
 * PARAMETERS:
 *   _account_id - Account ID to query
 *   _from       - Starting block number (NULL for beginning)
 *   _to         - Ending block number (NULL for the last irreversible block)
 *
 * RETURNS: hafah_backend.account_filter_return - range parameters
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_range(
    _account_id    INT,
    _from          INT,
    _to            INT
)
RETURNS hafah_backend.account_filter_return -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS $$
DECLARE
  __to INT;
  __from INT;
  __to_seq INT;
  __from_seq INT;
  __current_block INT := hive.app_get_irreversible_block();
BEGIN
  __to_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE
      ao.account_id = _account_id AND
      ao.operation_id < hafd.operation_id(LEAST(COALESCE(_to, __current_block), __current_block) + 1, 0)
    ORDER BY ao.account_op_seq_no DESC LIMIT 1
  );

  __from_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE
      ao.account_id = _account_id AND
      (_from IS NULL OR ao.operation_id >= hafd.operation_id(_from, 0))
    ORDER BY ao.account_op_seq_no ASC LIMIT 1
  );

  __to := (
    CASE
      WHEN (_to IS NULL) THEN
        __current_block
      WHEN (_to IS NOT NULL) AND (__current_block < _to) THEN
        __current_block
      ELSE
        _to
    END
  );

  __from := (
    CASE
      WHEN (_from IS NULL) THEN
        1
      ELSE
        _from
    END
  );

  RETURN (__from, __to, __from_seq, __to_seq)::hafah_backend.account_filter_return;
END
$$;

/*
 * ===================================================================================
 * total_pages
 * ===================================================================================
 * PURPOSE: Calculates total number of pages for a given item count and page size.
 *
 * PARAMETERS:
 *   _ops_count - Total number of items
 *   _page_size - Items per page
 *
 * RETURNS: INT - total number of pages
 */
CREATE OR REPLACE FUNCTION hafah_backend.total_pages(
    _ops_count    INT,
    _page_size    INT
)
RETURNS INT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' IMMUTABLE
AS $$
BEGIN
  RETURN (
    CASE
      WHEN (_ops_count % _page_size) = 0 THEN
        _ops_count / _page_size
      ELSE
        (_ops_count / _page_size) + 1
    END
  );
END
$$;

/*
 * ===================================================================================
 * get_account_operations_count
 * ===================================================================================
 * PURPOSE: Counts operations for an account within a sequence number range,
 *          optionally filtered by operation types. Used in account page endpoint.
 *
 * INDEX USAGE:
 *   - unfiltered: no scan, the range length is the count
 *   - filtered, range covering the account's whole history: index(-only) scan of
 *     hive_account_operations_account_id_op_type_id_idx (no seq predicate)
 *   - filtered, bounded range: the same index plus a heap fetch per match
 *
 * PARAMETERS:
 *   _operations - Array of operation type IDs to filter (NULL for all)
 *   _account_id - Account ID to count operations for
 *   _from_seq   - Starting sequence number
 *   _to_seq     - Ending sequence number
 *
 * RETURNS: BIGINT - count of matching operations
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_account_operations_count(
    _operations    INT[],
    _account_id    INT,
    _from_seq      INT,
    _to_seq        INT
)
RETURNS BIGINT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET from_collapse_limit = 16
SET join_collapse_limit = 16
SET enable_hashjoin = OFF
SET JIT = OFF
AS $$
DECLARE
  __first_seq INT;
  __last_seq INT;
BEGIN
  IF _operations IS NULL THEN
    RETURN _to_seq - _from_seq + 1;
  END IF;

  __first_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
    ORDER BY ao.account_op_seq_no ASC LIMIT 1
  );

  __last_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
    ORDER BY ao.account_op_seq_no DESC LIMIT 1
  );

  -- hive_account_operations_account_id_op_type_id_idx lacks account_op_seq_no, so
  -- a seq predicate turns the count into a heap fetch per matching row; when the
  -- range covers the whole history the predicate filters nothing and is dropped.
  IF _from_seq <= __first_seq AND _to_seq >= __last_seq THEN
    RETURN (
      SELECT COUNT(*)
      FROM hafd.account_operations ao
      WHERE ao.account_id = _account_id
        AND ao.op_type_id = ANY(_operations)
    );
  END IF;

  RETURN (
    SELECT COUNT(*)
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
      AND (_operations IS NULL OR ao.op_type_id = ANY(_operations))
      AND ao.account_op_seq_no >= _from_seq
      AND ao.account_op_seq_no <= _to_seq
  );
END
$$;

/*
 * ===================================================================================
 * account_rare_match_threshold
 * ===================================================================================
 * PURPOSE: The number of matches M below which a type-filtered page is cheaper
 *          to read through hive_account_operations_account_id_op_type_id_idx
 *          than with the two-step walk of hive_account_operations_uq1
 *          (account_id, account_op_seq_no) INCLUDE (op_type_id).
 *
 * COST MODEL (pages read, N = operations in the range, R = _rows):
 *   - two-step: step 1 scans about R * N / M uq1 entries index-only, T to a
 *     page; step 2 fetches up to R heap rows: R * N / (M * T) + R
 *   - type index: one heap fetch per match: M
 *   They are equal at M^2 - R * M - R * N / T = 0, so
 *     M* = (R + sqrt(R^2 + 4 * R * N / T)) / 2.
 *
 *   T = 260, measured on steem-18 (2026-10-13): the uq1 layout with op_type_id
 *   included, built there as a test index, holds 9.055e9 entries in 34.82M
 *   pages. Two scans there agree: step 1 for account 1475078 (transfers,
 *   M = 28) scans all its N = 9.54M entries in 36.6k pages, and for 440 scans
 *   1.56M entries in 6.0k pages, 259 a page, with 8 heap fetches.
 *   The fit picks the measured cheaper branch for every account measured
 *   (R = 1000, transfers): 440 (N 8.17M, M 864k, M* 6.1k), 509861 (16.0M,
 *   2.72M, 8.4k), 1157375 (13.8M, 13.2M, 7.8k), 492651 (1.20M, 55.5k, 2.7k) and
 *   120951 (1.07M, 26.1k, 2.6k) walk; 1475078 (9.54M, 28, 6.6k) reads by type.
 *
 *   Until hive_account_operations_uq1 includes op_type_id (HAF#364), step 1
 *   fetches the heap row of every entry it scans, R * N / M pages, and the
 *   two costs are equal at M = sqrt(R * N): that is returned instead, so the
 *   choice stays right on a HAF that lacks the column.
 *
 * PARAMETERS:
 *   _rows  - Rows the page query keeps (offset plus limit)
 *   _range - N, the operations in the range the page query reads
 *
 * RETURNS: BIGINT - M*, rounded up
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_rare_match_threshold(
    _rows     INT,
    _range    BIGINT
)
RETURNS BIGINT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __index_entries_per_page CONSTANT FLOAT8 := 260;
BEGIN
  IF NOT (
    SELECT i.indnatts > i.indnkeyatts
    FROM pg_index i
    WHERE i.indexrelid = 'hafd.hive_account_operations_uq1'::REGCLASS
  ) THEN
    RETURN ceil(sqrt(_rows::FLOAT8 * _range));
  END IF;

  RETURN ceil(
    (_rows + sqrt(_rows::FLOAT8 * _rows + 4 * _rows::FLOAT8 * _range / __index_entries_per_page)) / 2
  );
END
$$;

/*
 * ===================================================================================
 * account_op_types_are_rare
 * ===================================================================================
 * PURPOSE: Chooses how a type-filtered page of an account's history is read:
 *          the two-step walk of hive_account_operations_uq1 or every match
 *          through hive_account_operations_account_id_op_type_id_idx, sorted.
 *          The planner cannot judge M (nothing records how often a type occurs
 *          for one account), so M is counted up to the break-even of the two,
 *          account_rare_match_threshold.
 *
 * INDEX USAGE:
 *   - range covering the account's whole history: index-only scan of
 *     hive_account_operations_account_id_op_type_id_idx (no seq predicate)
 *   - bounded range: the same index plus a heap fetch per match examined
 *
 * PARAMETERS:
 *   _operations - Array of operation type IDs (NULL for all: never rare)
 *   _account_id - Account ID
 *   _from_seq   - Lowest sequence number the page query reads
 *   _to_seq     - Highest sequence number the page query reads; callers bound
 *                 it by the last irreversible block
 *   _rows       - Rows the page query keeps (offset plus limit)
 *
 * RETURNS: BOOLEAN - TRUE when fewer than account_rare_match_threshold(_rows, N)
 *          operations in [_from_seq, _to_seq] match _operations; FALSE for an
 *          empty range
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_op_types_are_rare(
    _operations    INT[],
    _account_id    INT,
    _from_seq      INT,
    _to_seq        INT,
    _rows          INT
)
RETURNS BOOLEAN -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS $$
DECLARE
  __threshold BIGINT;
  __first_seq INT;
  __last_seq INT;
BEGIN
  IF _operations IS NULL OR _from_seq IS NULL OR _to_seq IS NULL OR _to_seq < _from_seq THEN
    RETURN FALSE;
  END IF;

  __threshold := hafah_backend.account_rare_match_threshold(_rows, _to_seq::BIGINT - _from_seq + 1);

  __first_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
    ORDER BY ao.account_op_seq_no ASC LIMIT 1
  );

  __last_seq := (
    SELECT ao.account_op_seq_no
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
    ORDER BY ao.account_op_seq_no DESC LIMIT 1
  );

  -- As in get_account_operations_count: a seq predicate costs a heap fetch per
  -- match, and over the whole history it filters nothing, so it is dropped.
  IF _from_seq <= __first_seq AND _to_seq >= __last_seq THEN
    RETURN (
      SELECT count(*) < __threshold
      FROM (
        SELECT
        FROM hafd.account_operations ao
        WHERE ao.account_id = _account_id
          AND ao.op_type_id = ANY(_operations)
        LIMIT __threshold
      ) matches
    );
  END IF;

  RETURN (
    SELECT count(*) < __threshold
    FROM (
      SELECT
      FROM hafd.account_operations ao
      WHERE ao.account_id = _account_id
        AND ao.op_type_id = ANY(_operations)
        AND ao.account_op_seq_no >= _from_seq
        AND ao.account_op_seq_no <= _to_seq
      LIMIT __threshold
    ) matches
  );
END
$$;

/*
 * ===================================================================================
 * account_rare_op_matches
 * ===================================================================================
 * PURPOSE: account_op_types_are_rare for the include variants, whose page query
 *          also requires a transacting account. That column is not in
 *          hive_account_operations_account_id_op_type_id_idx, so the count
 *          fetches the heap row of every type match it examines, the very rows
 *          the rare page query reads. The count therefore keeps them: when they
 *          are rare, they are every match and the page is built from them.
 *
 * INDEX USAGE:
 *   - hive_account_operations_account_id_op_type_id_idx plus a heap fetch per
 *     type match examined, stopping at account_rare_match_threshold(_rows, N)
 *     matches
 *
 * PARAMETERS:
 *   _operations - Array of operation type IDs (NULL for all: never rare)
 *   _account_id - Account ID
 *   _from_seq   - Lowest sequence number the page query reads
 *   _to_seq     - Highest sequence number the page query reads; callers bound
 *                 it by the last irreversible block
 *   _rows       - Rows the page query keeps (offset plus limit)
 *   _transacting_account_ids - A match must have one of these transacting accounts
 *
 * RETURNS: hafah_backend.account_op_match[] - every operation in
 *          [_from_seq, _to_seq] matching _operations and _transacting_account_ids,
 *          unordered, when there are fewer than account_rare_match_threshold(_rows, N)
 *          of them; NULL otherwise (the two-step walk of hive_account_operations_uq1)
 *          and for an empty range
 */
CREATE OR REPLACE FUNCTION hafah_backend.account_rare_op_matches(
    _operations    INT[],
    _account_id    INT,
    _from_seq      INT,
    _to_seq        INT,
    _rows          INT,
    _transacting_account_ids INT[]
)
RETURNS hafah_backend.account_op_match[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET plan_cache_mode = force_custom_plan
AS $$
DECLARE
  __threshold BIGINT;
  __matches hafah_backend.account_op_match[];
BEGIN
  IF _operations IS NULL OR _from_seq IS NULL OR _to_seq IS NULL OR _to_seq < _from_seq THEN
    RETURN NULL;
  END IF;

  __threshold := hafah_backend.account_rare_match_threshold(_rows, _to_seq::BIGINT - _from_seq + 1);

  -- The heap row is fetched for the transacting account anyway, so the seq
  -- predicate costs nothing here, unlike in account_op_types_are_rare.
  __matches := ARRAY(
    SELECT (ao.operation_id, ao.op_type_id, ao.account_op_seq_no)::hafah_backend.account_op_match
    FROM hafd.account_operations ao
    WHERE ao.account_id = _account_id
      AND ao.op_type_id = ANY(_operations)
      AND ao.transacting_account_id = ANY(_transacting_account_ids)
      AND ao.account_op_seq_no >= _from_seq
      AND ao.account_op_seq_no <= _to_seq
    LIMIT __threshold
  );

  IF cardinality(__matches) < __threshold THEN
    RETURN __matches;
  END IF;

  RETURN NULL;
END
$$;

RESET ROLE;
