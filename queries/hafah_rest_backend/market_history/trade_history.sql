SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.trade_history(
    _from_block INT,
    _to_block INT, 
    _limit INT
)
RETURNS SETOF hafah_backend.fill_order -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY
  WITH recent_operations AS MATERIALIZED (
    SELECT 
      ov.block_num,
      ov.body 
    FROM hive.operations_view ov
    WHERE
      ov.op_type_id = 57 AND
      ov.block_num >= _from_block AND
      ov.block_num <= _to_block
    ORDER BY ov.block_num, ov.id 
    LIMIT _limit
  )
  SELECT
    foo.current_pays,
    foo.date,
    foo.maker,
    foo.open_pays,
    foo.taker
  FROM recent_operations ro
  JOIN hive.blocks_view bv ON bv.num = ro.block_num
  CROSS JOIN hafah_backend.process_fill_order_operation(ro.body, bv.created_at) foo;
END
$$;

RESET ROLE;
