SET ROLE hafah_owner;

DROP TYPE IF EXISTS hafah_backend.calculate_pages_return CASCADE;
CREATE TYPE hafah_backend.calculate_pages_return AS
(
    rest_of_division INT,
    total_pages INT,
    page_num INT,
    offset_filter INT,
    limit_filter INT
);

CREATE OR REPLACE FUNCTION hafah_backend.calculate_pages(
    _count INT,
    _page INT,
    _order_is hafah_backend.sort_direction, -- noqa: LT01, CP05
    _limit INT
)
RETURNS hafah_backend.calculate_pages_return -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS
$$
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
        WHEN _order_is = 'desc' AND __page = 1             AND __rest_of_division != 0 THEN
          __rest_of_division 
        WHEN _order_is = 'asc'  AND __page = __total_pages AND __rest_of_division != 0 THEN
          __rest_of_division 
        ELSE 
          _limit 
        END
    );

  PERFORM hafah_python.validate_page(_page, __total_pages);

  RETURN (__rest_of_division, __total_pages, __page, __offset, __limit)::hafah_backend.calculate_pages_return;
END
$$;

DROP TYPE IF EXISTS hafah_backend.account_filter_return CASCADE;
CREATE TYPE hafah_backend.account_filter_return AS
(
    count INT,
    from_seq INT,
    to_seq INT
);

CREATE OR REPLACE FUNCTION hafah_backend.account_range(
    _operations INT [],
    _account_id INT,
    _from INT, 
    _to INT
)
RETURNS hafah_backend.account_filter_return -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
AS
$$
DECLARE 
  __to_seq INT;
  __from_seq INT;
  __count INT;
BEGIN
  /*
  we are using 3 diffrent methods of fetching data,
  1. using hive_account_operations_uq_1 (account_id, account_op_seq_no) when __no_filters = FALSE (when 2. and 3. are TRUE)
    - when we don't use filter we can page the result by account_op_seq_no, 
      we need to add ORDER BY account_op_seq_no
  2. using hive_account_operations_uq2 (account_id, operation_id) when __no_end_date = FALSE OR __no_start_date = FALSE
    - when we filter operations ONLY by block_num (converted to operation_id), 
      we need to add ORDER BY operation_id
  3. using hive_account_operations_type_account_id_op_seq_idx (op_type_id, account_id, account_op_seq_no) when __no_ops_filter = FALSE
    - when we filter operations by op_type_id 
    - when we filter operations by op_type_id AND block_num (converted to operation_id)
  */ 
  
  __to_seq := (
    SELECT 
      aov.account_op_seq_no
    FROM hive.account_operations_view aov
    WHERE 
      aov.account_id = _account_id AND
      (_to IS NULL OR aov.block_num <= _to)
    ORDER BY aov.account_op_seq_no DESC LIMIT 1
  );

  __from_seq := (
    SELECT 
      aov.account_op_seq_no
    FROM hive.account_operations_view aov
    WHERE 
      aov.account_id = _account_id AND
      (_from IS NULL OR aov.block_num >= _from)
    ORDER BY aov.account_op_seq_no ASC LIMIT 1
  );

  __count := hafah_backend.get_account_operations_count(_operations, _account_id, __from_seq, __to_seq);

  RETURN (__count, __from_seq, __to_seq)::hafah_backend.account_filter_return;
END
$$;

RESET ROLE;
