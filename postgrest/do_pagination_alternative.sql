/*
VERY SLOW RESPONSES UNDER LOAD, NEEDS INVESTIGATION

CREATE OR REPLACE FUNCTION hafah_objects.do_pagination(_block_range_end INT, _limit INT, _len INT, ops_json JSONB, _fill_operation_id BOOLEAN, _group_by_block BOOLEAN)
RETURNS JSON
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  IF _len > 0 AND _len = _limit THEN
    RETURN
      jsonb_set(ops, '{next_operation_begin}', to_jsonb(next_operation_begin))
    FROM (
      SELECT
        (SELECT jsonb_set(ops_json, '{next_block_range_begin}', to_jsonb(next_block_range_begin))) AS ops,
        hafah_objects.set_operation_id(next_operation_begin, _fill_operation_id) AS next_operation_begin
      FROM (
        SELECT
          (CASE WHEN o.block_num IS NULL THEN 0 ELSE
            (CASE WHEN o.block_num >= _block_range_end THEN 0 ELSE o.block_num END)
          END) AS next_block_range_begin,
          (CASE WHEN o.id IS NULL THEN 0 ELSE
          -- TODO: (SELECT hafah_objects.set_operation_id(o.id, _fill_operation_id))
          (SELECT o.id)
          END) AS next_operation_begin
        FROM
          hive.operations o
        JOIN hive.operation_types ot ON o.op_type_id = ot.id
        WHERE
          CASE WHEN _group_by_block IS TRUE THEN
            ot.is_virtual = TRUE AND
            o.block_num >= (ops_json->'ops_by_block'->-1->'block')::INT AND
            o.id > (ops_json->'ops_by_block'->-1->'ops'->-1->'operation_id')::BIGINT
          ELSE
            ot.is_virtual = TRUE AND
            o.block_num >= (ops_json->'ops'->-1->>'block')::INT AND
            o.id > (ops_json->'ops'->-1->>'operation_id')::BIGINT
          END
        ORDER BY o.block_num, o.id 
        LIMIT 1
      ) result
    ) insert_result;
  ELSE
    RETURN
      jsonb_set(ops, '{next_operation_begin}', to_jsonb(0))
    FROM (
      SELECT
        jsonb_set(ops_json, '{next_block_range_begin}', to_jsonb(_block_range_end)) AS ops
      ) insert_result;
  END IF;
END
$$
;
*/