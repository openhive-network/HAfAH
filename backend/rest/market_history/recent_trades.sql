SET ROLE hafah_owner;

/*
 * recent_trades.sql: REST API backend for recent market trades.
 *
 * Called by: hafah_endpoints.get_recent_trades() in endpoints/market_history/get_recent_trades.sql
 *
 * REST Endpoint: GET /market-history/recent-trades
 *
 * NOTE: Uses fill_order_operation (op_type_id=57) to track internal market trades.
 */

/*
 * ===================================================================================
 * process_fill_order_operation
 * ===================================================================================
 * PURPOSE: Convert a fill_order operation body into structured fill_order type.
 *          Internal helper for market history functions.
 *
 * PARAMETERS:
 *   _operation_body - JSONB operation body containing fill_order data
 *   _timestamp      - Block timestamp for the trade
 *
 * RETURNS: Structured fill_order with current_pays, open_pays, maker, taker, and date
 */
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

/*
 * ===================================================================================
 * recent_trades
 * ===================================================================================
 * PURPOSE: Retrieve the most recent market trades (fill_order operations).
 *          Returns trades in reverse chronological order.
 *
 * PARAMETERS:
 *   _limit - Maximum number of trades to return
 *
 * RETURNS: Set of fill_order records representing recent trades
 */
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
