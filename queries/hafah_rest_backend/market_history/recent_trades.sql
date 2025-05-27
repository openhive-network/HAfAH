SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.process_fill_order_operation(IN _operation_body JSONB, IN _timestamp TIMESTAMP)
RETURNS hafah_backend.fill_order
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  _open_pays hafah_backend.nai_object := jsonb_populate_record(NULL::hafah_backend.nai_object, _operation_body->'value'->'open_pays');
  _current_pays hafah_backend.nai_object := jsonb_populate_record(NULL::hafah_backend.nai_object, _operation_body->'value'->'current_pays');
BEGIN
  RETURN (
    _current_pays,
    _timestamp,
    _operation_body->'value'->>'open_owner',
    _open_pays,
    _operation_body->'value'->>'current_owner'
  )::hafah_backend.fill_order; 
END
$$;

CREATE OR REPLACE FUNCTION hafah_backend.recent_trades(
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
    WHERE ov.op_type_id = 57 
    ORDER BY ov.block_num DESC, ov.id DESC 
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
