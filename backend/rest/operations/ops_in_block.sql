SET ROLE hafah_owner;

/*
 * ops_in_block.sql: REST API backend for operations in block range queries.
 *
 * Called by:
 *   - hafah_endpoints.get_operations() in endpoints/operations/get_operations.sql
 *   - hafah_endpoints.get_block_operations() in endpoints/blocks/get_block_operations.sql
 *
 * REST Endpoints:
 *   - GET /operations?from-block={n}&to-block={m}
 *   - GET /blocks/{block-num}/operations
 */

/*
 * ===================================================================================
 * get_ops_in_blocks
 * ===================================================================================
 * PURPOSE: Retrieve operations from a block range with pagination support.
 *          Supports filtering by operation types and virtual/non-virtual operations.
 *
 * PARAMETERS:
 *   _block_num             - Starting block number
 *   _end_block_num         - Ending block number
 *   _operation_group_types - Filter: TRUE=virtual only, FALSE=non-virtual only, NULL=all
 *   _operation_types       - Array of operation type IDs to filter by
 *   _operation_begin       - Operation ID to start from (-1 for beginning)
 *   _limit                 - Maximum number of operations to return
 *   _include_reversible    - Whether to include reversible blocks
 *   _is_legacy_style       - Whether to use legacy operation format
 *
 * RETURNS: Operations with next block number for cursor-based pagination
 *
 * DATA SOURCES:
 *   - hafah_backend.get_ops_in_blocks_helper(): Core query execution
 *   - hafd.blocks: Head block lookup for range clamping
 *
 * PAGINATION: Cursor-based using operation_id
 *   - Returns next_block_num and next_operation_id for continuation
 *   - If result count < limit, no more data exists
 *   - Client uses returned cursor for next request
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_blocks(
    in _block_num INT,
    in _end_block_num INT,
    in _operation_group_types BOOLEAN,
    in _operation_types INT[],
    in _operation_begin BIGINT,
    in _limit INT,
    in _include_reversible BOOLEAN,
    in _is_legacy_style BOOLEAN
)
RETURNS hafah_backend.operations_in_block_range
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  _operations hafah_backend.operation[];
  _operation_id TEXT;
  _next_block_num INT;

  -- Head block: Used to clamp end_block_num to avoid querying future blocks
  _latest_block_num INT := (SELECT num FROM hafd.blocks ORDER BY num DESC LIMIT 1);
BEGIN
  WITH pre_result AS (
    SELECT
      hp.__block_num AS "block",
      hp._value::jsonb AS "op",
      hp._op_in_trx AS "op_in_trx",
      hp._op_type_id AS "op_type_id",
      hp._timestamp AS "timestamp",
      hp._trx_id AS "trx_id",
      hp._trx_in_block AS "trx_in_block",
      hp._virtual_op AS "virtual_op",
      hp._operation_id AS "operation_id"
    FROM hafah_backend.get_ops_in_blocks_helper(
      _block_num,
      -- Clamp end block to head block + 1 to avoid querying non-existent blocks
      -- Helper uses exclusive end, so +1 gives inclusive behavior
      (CASE WHEN _end_block_num > _latest_block_num THEN _latest_block_num + 1 ELSE _end_block_num + 1 END),
      _operation_group_types,
      _operation_types,
      _operation_begin,
      _limit,
      _include_reversible,
      _is_legacy_style
    ) AS hp
  ),
  -- Cursor pagination logic: Determine if more results exist
  count_logic AS MATERIALIZED (
    SELECT COUNT(*) as count FROM pre_result
  ),
  -- Calculate next cursor position for pagination
  -- If count = limit, more data exists; use last operation as cursor
  -- If count < limit, no more data; return end_block_num as terminal
  paging_logic AS MATERIALIZED (
    SELECT (
      CASE
        WHEN (SELECT count FROM count_logic) = _limit THEN
          pre_result.block
        ELSE
          _end_block_num
        END
      ) AS block_num,
      (
      CASE
        WHEN (SELECT count FROM count_logic) = _limit THEN
          pre_result.operation_id
        ELSE
          0  -- 0 signals no more data
        END
      ) AS id
    FROM pre_result
    WHERE pre_result.operation_id = (SELECT MAX(pre_result.operation_id) FROM pre_result)
    LIMIT 1
  )
  SELECT
    COALESCE((SELECT block_num FROM paging_logic), 0)::INT,
    COALESCE((SELECT id FROM paging_logic), 0)::TEXT,
    (
      -- Aggregate operations in order by operation_id
      SELECT array_agg(rows ORDER BY rows.operation_id::BIGINT)
      FROM (
        SELECT
          s.op,
          s.block,
          s.trx_id,
          s.op_in_trx::INT,
          s.op_type_id,
          s.timestamp,
          s.virtual_op,
          s.operation_id::TEXT,
          s.trx_in_block::SMALLINT
        FROM pre_result s
      ) rows
    )
  INTO _next_block_num, _operation_id, _operations;

  -- Return composite with cursor info for next page request
  RETURN (_next_block_num, _operation_id, COALESCE(_operations, '{}'::hafah_backend.operation[]))::hafah_backend.operations_in_block_range;

END
$$;

/*
 * ===================================================================================
 * get_ops_in_blocks_helper
 * ===================================================================================
 * PURPOSE: Internal helper function for get_ops_in_blocks. Handles the actual
 *          query execution with proper reversibility checking and filtering.
 *
 * PARAMETERS: Same as get_ops_in_blocks
 *
 * RETURNS: Table of operation data for aggregation by the main function
 *
 * DATA SOURCES:
 *   - hafah_backend.helper_operations_view: Optimized operations view
 *   - hive.transactions_view: Transaction hash lookup
 *   - hive.blocks_view: Block timestamp lookup
 *   - hafd.operation_types: Type filtering validation
 *
 * REVERSIBILITY:
 *   - hive.app_get_irreversible_block(): Returns last irreversible block number
 *   - If _include_reversible=FALSE, clamps query to irreversible blocks only
 *   - Irreversible data can be cached for 1 year; reversible only 2 seconds
 *
 * NOTE: Also used by JSON-RPC API for enum_virtual_ops and get_ops_in_block
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_blocks_helper(
    in _block_num INT,
    in _end_block_num INT,
    in _operation_group_types BOOLEAN,
    in _operation_types INT[],
    in _operation_begin BIGINT,
    in _limit INT,
    in _include_reversible BOOLEAN,
    in _is_legacy_style BOOLEAN
)
RETURNS TABLE(
    __block_num INT,
    _trx_id TEXT,
    _trx_in_block BIGINT,
    _op_in_trx BIGINT,
    _op_type_id INT,
    _virtual_op BOOLEAN,
    _timestamp TEXT,
    _value TEXT,
    _operation_id BIGINT
)
AS
$function$
DECLARE
  -- NULL = all operations; TRUE/FALSE filters virtual/non-virtual
  __operation_filter BOOLEAN = (_operation_group_types IS NULL);
  __resolved_filter_exists BOOLEAN;
BEGIN
  -- REVERSIBILITY CHECK: If only irreversible data requested, validate block range
  -- Case 1: Start block is beyond irreversible - return empty result
  IF (NOT _include_reversible) AND _block_num > hive.app_get_irreversible_block() THEN
    RETURN QUERY SELECT
      NULL::INT, -- _block_num
      NULL::TEXT, -- _trx_id
      NULL::BIGINT, -- _trx_in_block
      NULL::BIGINT, -- _op_in_trx
      NULL::INT, -- _op_type_id
      NULL::BOOLEAN, -- _virtual_op
      NULL::TEXT, -- _timestamp
      NULL::TEXT, -- _value
      NULL::BIGINT  -- _operation_id
    LIMIT 0;
    RETURN;
  -- Case 2: End block extends into reversible - clamp to irreversible boundary
  ELSEIF (NOT _include_reversible) AND _end_block_num > hive.app_get_irreversible_block() THEN
    _end_block_num := hive.app_get_irreversible_block() + 1;
  END IF;

  -- Check if specific operation type filter was provided
  __resolved_filter_exists := array_length( _operation_types, 1 ) IS NOT NULL;

  RETURN QUERY
    WITH hfm_operations AS (
      SELECT
        T.block_num __block_num,
        -- Transaction hash handling: Virtual ops have no transaction
        -- Use zero-hash sentinel for virtual operations
        (
          CASE
          WHEN T2.trx_hash IS NULL THEN '0000000000000000000000000000000000000000'
          ELSE encode( T2.trx_hash, 'hex')  -- Binary-to-hex: 32 bytes
          END
        ) _trx_id,
        -- Transaction position: -1 sentinel for virtual operations
        (
          CASE
          WHEN T2.trx_in_block IS NULL THEN -1
          ELSE T2.trx_in_block
          END
        )::BIGINT _trx_in_block,
        T.op_pos _op_in_trx,
        T.op_type_id _op_type_id,
        T.virtual_op _virtual_op,
        -- Operation body: Support legacy and modern formats
        (
          CASE
            WHEN _is_legacy_style THEN hive.get_legacy_style_operation(T.body_binary)::text
            ELSE T.body :: text
          END
        ) AS _value,
        T.id::BIGINT _operation_id
      FROM
        (
          -- UNION pattern: Separate queries for type-filtered vs unfiltered
          -- This allows PostgreSQL to use different indexes optimally
          WITH accepted_types AS MATERIALIZED
          (
            -- Validate and cache accepted operation types
            SELECT ot.id FROM hafd.operation_types ot WHERE __resolved_filter_exists AND ot.id=ANY(_operation_types)
          )
          -- Branch 1: Type-filtered query (when _operation_types provided)
          (
            SELECT
              ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
            FROM hafah_backend.helper_operations_view ho
            JOIN accepted_types t ON ho.op_type_id = t.id
            WHERE __resolved_filter_exists AND (
                (block_num >= _block_num) AND
                (block_num < _end_block_num ) AND
                -- Cursor-based pagination: Skip operations before cursor
                ( _operation_begin = -1 OR ho.id > _operation_begin )
            )
            ORDER BY ho.id
            LIMIT _limit
          )
          UNION ALL
          -- Branch 2: Unfiltered or virtual-only query
          (
            SELECT
              ho.id, ho.block_num, ho.trx_in_block, ho.op_pos, ho.body, ho.body_binary, ho.op_type_id, ho.virtual_op
            FROM hafah_backend.helper_operations_view ho
            WHERE NOT __resolved_filter_exists AND (
                (block_num >= _block_num) AND
                (block_num < _end_block_num ) AND
                -- Virtual filter: NULL=all, TRUE=virtual only, FALSE=non-virtual only
                (__operation_filter OR (ho.virtual_op = _operation_group_types)) AND
                ( _operation_begin = -1 OR ho.id > _operation_begin )
              )
            ORDER BY ho.id
            LIMIT _limit
          )
        ) T
      -- LEFT JOIN transactions: Virtual ops won't match (have no transaction)
      LEFT JOIN
        (
          SELECT
            trx_hash, trx_in_block, block_num
          FROM hive.transactions_view
          WHERE
            (block_num >= _block_num) AND
            (block_num < _end_block_num)
        ) T2 ON T.block_num = T2.block_num AND T.trx_in_block = T2.trx_in_block
      WHERE T.block_num >= _block_num AND T.block_num < _end_block_num
      ORDER BY T.id
      LIMIT _limit
    )
    SELECT
      pre_result.__block_num,
      pre_result._trx_id,
      pre_result._trx_in_block,
      pre_result._op_in_trx,
      pre_result._op_type_id::INT,
      pre_result._virtual_op,
      -- Timestamp from block, formatted without JSON quotes
      trim(both '"' from to_json(hb.created_at)::text) _timestamp,
      pre_result._value,
      pre_result._operation_id
    FROM hfm_operations pre_result
    -- JOIN blocks_view for timestamp
    JOIN hive.blocks_view hb ON hb.num = pre_result.__block_num
    WHERE hb.num >= _block_num AND hb.num < _end_block_num
    ORDER BY pre_result._operation_id;
END
$function$
language plpgsql STABLE
SET JIT=OFF;

/*
 * ===================================================================================
 * get_ops_by_block
 * ===================================================================================
 * PURPOSE: Retrieve operations from a single block with filtering and pagination.
 *          Supports filtering by operation type, account, and operation body keys.
 *
 * PARAMETERS:
 *   _block_num    - Block number to query
 *   _page_num     - Page number (1-based)
 *   _page_size    - Number of results per page
 *   _filter       - Array of operation type IDs to filter by
 *   _order_is     - Sort direction ('asc' or 'desc')
 *   _body_limit   - Maximum size for operation body (-1 for unlimited)
 *   _account_id   - Filter by account ID (NULL for all accounts)
 *   _key_content  - Array of values to match in operation body
 *   _setof_keys   - JSON array of key paths for body filtering
 *
 * RETURNS: Set of operations matching the criteria
 *
 * DATA SOURCES:
 *   - hive.operations_view: Operation bodies and metadata
 *   - hive.account_operations_view: Account-to-operation mapping
 *   - hafd.operation_types: is_virtual flag lookup
 *   - hive.transactions_view: Transaction hash lookup
 *   - hive.blocks_view: Block timestamp
 *
 * PAGINATION: Offset-based (page-based)
 *   - Page 1 = most recent when desc, oldest when asc
 *   - offset = (page_num - 1) * page_size
 *
 * NOTES:
 *   - Two query branches: with/without account filter
 *   - Body filtering uses jsonb_extract_path_text for nested key lookup
 *   - Large bodies can be truncated via operation_body_filter()
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_block(
    _block_num INT,
    _page_num INT,
    _page_size INT,
    _filter INT [],
    _order_is hafah_backend.sort_direction, -- noqa: LT01, CP05
    _body_limit INT,
    _account_id INT,
    _key_content TEXT [],
    _setof_keys JSON
)
RETURNS SETOF hafah_backend.operation -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __no_ops_filter BOOLEAN = (_filter IS NULL);
  -- Offset-based pagination: Calculate starting position
  _offset INT := (_page_num - 1) * _page_size;
  -- Body key filter flags: NULL = skip filter for that position
  _first_key BOOLEAN = (_key_content[1] IS NULL);
  _second_key BOOLEAN = (_key_content[2] IS NULL);
  _third_key BOOLEAN = (_key_content[3] IS NULL);
BEGIN

-- Branch 1: No account filter - query all operations in block
IF _account_id IS NULL THEN
  RETURN QUERY
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.id,
      ls.block_num,
      ls.trx_in_block,
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ls.op_pos,
      ls.op_type_id,
      ls.body,
      hot.is_virtual
    FROM (
      With operations_in_block AS
      (
      SELECT ov.id, ov.trx_in_block, ov.op_pos, ov.body, ov.op_type_id, ov.block_num
      FROM hive.operations_view ov
      WHERE
        ov.block_num = _block_num
      ),
      filter_ops AS MATERIALIZED
      (
      SELECT *
      FROM operations_in_block oib
      WHERE
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
      )
      SELECT * FROM filter_ops fo
      ORDER BY
        (CASE WHEN _order_is = 'desc' THEN fo.id ELSE NULL END) DESC,
        (CASE WHEN _order_is = 'asc' THEN fo.id ELSE NULL END) ASC
      LIMIT _page_size
      OFFSET _offset
    ) ls
    -- JOIN operation_types: Required to get is_virtual flag
    JOIN hafd.operation_types hot ON hot.id = ls.op_type_id
    -- LEFT JOIN transactions: Virtual ops have no transaction (NULL trx_hash)
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ls.trx_in_block
    ORDER BY
      (CASE WHEN _order_is = 'desc' THEN ls.id ELSE NULL END) DESC,
      (CASE WHEN _order_is = 'asc' THEN ls.id ELSE NULL END) ASC)

  -- Body size limiting: Truncate large operation bodies
  -- Uses operation_body_filter() to handle oversized JSON gracefully
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id::TEXT,
      filtered_operations.trx_in_block::SMALLINT
    FROM (
    SELECT hafah_backend.operation_body_filter(opr.body, opr.id, _body_limit) as composite, opr.id, opr.block_num, opr.trx_in_block, opr.trx_hash, opr.op_pos, opr.op_type_id, opr.is_virtual, hb.created_at
    FROM operation_range opr
    -- JOIN blocks_view for timestamp
    JOIN hive.blocks_view hb ON hb.num = opr.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id, filtered_operations.trx_in_block, filtered_operations.op_pos;

-- Branch 2: With account filter - use account_operations_view for efficient lookup
ELSE

  RETURN QUERY
  WITH operation_range AS MATERIALIZED (
    SELECT
      ls.id,
      ls.block_num,
      ls.trx_in_block,
      -- Binary-to-hex: Transaction hash
      encode(htv.trx_hash, 'hex') AS trx_hash,
      ls.op_pos,
      ls.op_type_id,
      ls.body,
      hot.is_virtual
    FROM (
      -- Use account_operations_view: Index-optimized for account lookups
      WITH account_operations_in_block AS
      (
        SELECT aov.operation_id
        FROM hive.account_operations_view aov
        WHERE
          aov.account_id = _account_id AND
          aov.block_num = _block_num
      ),
      operations_in_block AS
      (
        SELECT ov.id, ov.trx_in_block, ov.op_pos, ov.body, ov.op_type_id, ov.block_num
        FROM hive.operations_view ov
        -- JOIN to account ops: Only operations involving this account
        JOIN account_operations_in_block aoib ON aoib.operation_id = ov.id
      ),
      filter_ops AS MATERIALIZED
      (
        SELECT *
        FROM operations_in_block oib
        WHERE
          (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
          (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
          (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
          (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
      )
      SELECT * FROM filter_ops fo
      ORDER BY
        (CASE WHEN _order_is = 'desc' THEN fo.id ELSE NULL END) DESC,
        (CASE WHEN _order_is = 'asc' THEN fo.id ELSE NULL END) ASC
      LIMIT _page_size
      OFFSET _offset
    ) ls
    JOIN hafd.operation_types hot ON hot.id = ls.op_type_id
    LEFT JOIN hive.transactions_view htv ON htv.block_num = ls.block_num AND htv.trx_in_block = ls.trx_in_block
    ORDER BY
      (CASE WHEN _order_is = 'desc' THEN ls.id ELSE NULL END) DESC,
      (CASE WHEN _order_is = 'asc' THEN ls.id ELSE NULL END) ASC)

  -- filter too long operation bodies
    SELECT
      (filtered_operations.composite).body,
      filtered_operations.block_num,
      filtered_operations.trx_hash,
      filtered_operations.op_pos,
      filtered_operations.op_type_id,
      filtered_operations.created_at,
      filtered_operations.is_virtual,
      filtered_operations.id::TEXT,
      filtered_operations.trx_in_block::SMALLINT
    FROM (
    SELECT hafah_backend.operation_body_filter(opr.body, opr.id, _body_limit) as composite, opr.id, opr.block_num, opr.trx_in_block, opr.trx_hash, opr.op_pos, opr.op_type_id, opr.is_virtual, hb.created_at
    FROM operation_range opr
    JOIN hive.blocks_view hb ON hb.num = opr.block_num
    ) filtered_operations
    ORDER BY filtered_operations.id, filtered_operations.trx_in_block, filtered_operations.op_pos;

END IF;

END
$$;

/*
 * ===================================================================================
 * get_ops_by_block_count
 * ===================================================================================
 * PURPOSE: Count operations in a block matching the specified filters.
 *          Used for pagination calculations (total_pages = count / page_size).
 *
 * PARAMETERS:
 *   _block_num    - Block number to query
 *   _filter       - Array of operation type IDs to filter by
 *   _account_id   - Filter by account ID (NULL for all accounts)
 *   _key_content  - Array of values to match in operation body
 *   _setof_keys   - JSON array of key paths for body filtering
 *
 * RETURNS: Count of matching operations
 *
 * DATA SOURCES:
 *   - hive.operations_view: All operations in block
 *   - hive.account_operations_view: Account-filtered operations
 *
 * NOTES:
 *   - Mirrors filter logic from get_ops_by_block but only counts
 *   - Used to calculate total pages for offset-based pagination
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_block_count(
    _block_num INT,
    _filter INT [],
    _account_id INT,
    _key_content TEXT [],
    _setof_keys JSON
)
RETURNS INT -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __no_ops_filter BOOLEAN = (_filter IS NULL);
  _first_key BOOLEAN = (_key_content[1] IS NULL);
  _second_key BOOLEAN = (_key_content[2] IS NULL);
  _third_key BOOLEAN = (_key_content[3] IS NULL);
BEGIN

-- Count branch 1: All operations in block (no account filter)
IF _account_id IS NULL THEN
  RETURN (
    WITH operations_in_block AS
    (
      SELECT ov.op_type_id, ov.body
      FROM hive.operations_view ov
      WHERE
        ov.block_num = _block_num
    ),
    filter_ops AS MATERIALIZED
    (
      SELECT oib.op_type_id
      FROM operations_in_block oib
      WHERE
        -- Operation type filter: NULL = all types, otherwise match array
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        -- Body key filters: Extract nested JSON values and compare
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
    )
    SELECT COUNT(*) FROM filter_ops);
-- Count branch 2: Account-filtered operations
ELSE
  RETURN (
    -- Use account_operations_view for efficient account lookup
    WITH account_operations_in_block AS
    (
      SELECT aov.operation_id
      FROM hive.account_operations_view aov
      WHERE
        aov.account_id = _account_id AND
        aov.block_num = _block_num
    ),
    operations_in_block AS
    (
      SELECT ov.op_type_id, ov.body
      FROM hive.operations_view ov
      JOIN account_operations_in_block aoib ON aoib.operation_id = ov.id
    ),
    filter_ops AS MATERIALIZED
    (
      SELECT oib.op_type_id
      FROM operations_in_block oib
      WHERE
        (__no_ops_filter OR oib.op_type_id = ANY(_filter)) AND
        (_first_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->0))) = _key_content[1]) AND
        (_second_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->1))) = _key_content[2]) AND
        (_third_key OR jsonb_extract_path_text(oib.body, variadic ARRAY(SELECT json_array_elements_text(_setof_keys->2))) = _key_content[3])
    )
    SELECT COUNT(*) FROM filter_ops);

END IF;

END
$$;

RESET ROLE;
