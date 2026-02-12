SET ROLE hafah_owner;

/*
 * paging.sql: Pagination helper functions.
 *
 * Types:
 *   - hafah_backend.calculate_pages_return - Return type for calculate_pages
 *   - hafah_backend.account_filter_return - Return type for account_range
 *
 * Functions:
 *   - hafah_backend.calculate_pages() - Calculate pagination parameters
 *   - hafah_backend.account_range() - Calculate account operation range
 *   - hafah_backend.total_pages() - Calculate total pages for given count
 *   - hafah_backend.get_account_operations_count() - Count operations for account
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
 *          Uses different indexing strategies based on filters:
 *          1. hive_account_operations_uq_1 - when no filters (page by account_op_seq_no)
 *          2. hive_account_operations_uq2 - when filtering by block_num only
 *          3. hive_account_operations_type_account_id_op_seq_idx - when filtering by op_type_id
 *
 * PARAMETERS:
 *   _operations - Array of operation type IDs to filter (NULL for all)
 *   _account_id - Account ID to query
 *   _from       - Starting block number (NULL for beginning)
 *   _to         - Ending block number (NULL for current block)
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
  __current_block INT := (SELECT bv.num FROM hive.blocks_view bv ORDER BY bv.num DESC LIMIT 1);
BEGIN
  __to_seq := (
    SELECT aov.account_op_seq_no
    FROM hive.account_operations_view aov
    WHERE
      aov.account_id = _account_id AND
      (_to IS NULL OR aov.block_num <= _to)
    ORDER BY aov.account_op_seq_no DESC LIMIT 1
  );

  __from_seq := (
    SELECT aov.account_op_seq_no
    FROM hive.account_operations_view aov
    WHERE
      aov.account_id = _account_id AND
      (_from IS NULL OR aov.block_num >= _from)
    ORDER BY aov.account_op_seq_no ASC LIMIT 1
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
BEGIN
  IF _operations IS NULL THEN
    RETURN _to_seq - _from_seq + 1;
  END IF;

  RETURN (
    SELECT COUNT(*)
    FROM hive.account_operations_view aov
    WHERE aov.account_id = _account_id
      AND (_operations IS NULL OR aov.op_type_id = ANY(_operations))
      AND aov.account_op_seq_no >= _from_seq
      AND aov.account_op_seq_no <= _to_seq
  );
END
$$;

RESET ROLE;
