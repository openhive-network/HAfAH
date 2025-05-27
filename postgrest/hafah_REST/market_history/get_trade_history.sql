SET ROLE hafah_owner;

/** openapi:paths
/market-history/trade-history:
  get:
    tags:
      - Market-history
    summary: Returns the most recent trades for the internal HBD:HIVE market.
    description: |

      SQL example
      * `SELECT * FROM hafah_endpoints.get_trade_history(''2016-08-15 19:47:21'', ''2016-09-15 19:47:21'',1000);`

      REST call example
      * `GET ''https://%1$s/hafah-api/market-history/trade-history?result-limit=100&from-block=2016-08-15 19:47:21&to-block==2016-09-15 19:47:21''`
    operationId: hafah_endpoints.get_trade_history
    parameters:
      - in: query
        name: from-block
        required: true
        schema:
          type: string
        description: |
          Lower limit of the block range, can be represented either by a block-number (integer) or a timestamp (in the format YYYY-MM-DD HH:MI:SS).

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is more than or equal to the given `timestamp` (i.e. `block''s created_at >= timestamp`).

          The function will interpret and convert the input based on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
      - in: query
        name: to-block
        required: true
        schema:
          type: string
        description: | 
          Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). 

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).
          
          The function will convert the value depending on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
      - in: query
        name: result-limit
        required: true
        schema:
          type: integer
        description: |
          A limit of retrieved orders
    responses:
      '200':
        description: |

          * Returns `hafah_backend.array_of_fill_order`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.array_of_fill_order'
            example: [
              {
                "current_pays": {
                  "amount": "1000",
                  "nai": "@@000000013",
                  "precision": 3
                },
                "date": "2025-04-26T11:45:57",
                "maker": "quicktrades",
                "open_pays": {
                  "amount": "3871",
                  "nai": "@@000000021",
                  "precision": 3
                },
                "taker": "elon.curator"
              },
              {
                "current_pays": {
                  "amount": "1939",
                  "nai": "@@000000021",
                  "precision": 3
                },
                "date": "2025-05-26T11:45:30",
                "maker": "quicktrades",
                "open_pays": {
                  "amount": "500",
                  "nai": "@@000000013",
                  "precision": 3
                },
                "taker": "cst90"
              }
            ]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_trade_history;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_trade_history(
    "from-block" TEXT,
    "to-block" TEXT,
    "result-limit" INT
)
RETURNS SETOF hafah_backend.fill_order 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  _block_range hive.blocks_range := hive.convert_to_blocks_range("from-block","to-block");
BEGIN
  PERFORM hafah_python.validate_limit("result-limit", 1000, 'result-limit');
  PERFORM hafah_python.validate_negative_limit("result-limit", 'result-limit');

  IF _block_range.first_block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('from-block');   
  END IF;

  IF _block_range.last_block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('to-block');
  END IF;

  IF _block_range.last_block <= hive.app_get_irreversible_block() AND _block_range.last_block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  RETURN QUERY (
    SELECT
      rt.current_pays,
      rt.date,
      rt.maker,
      rt.open_pays,
      rt.taker
    FROM hafah_backend.trade_history(_block_range.first_block, _block_range.last_block, "result-limit") rt
    ORDER BY rt.date
  );
END
$$
;

RESET ROLE;
