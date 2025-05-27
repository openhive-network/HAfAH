SET ROLE hafah_owner;

/** openapi:paths
/market-history/recent-trades:
  get:
    tags:
      - Market-history
    summary: Returns the most recent trades for the internal HBD:HIVE market.
    description: |

      SQL example
      * `SELECT * FROM hafah_endpoints.get_recent_trades(1000);`

      REST call example
      * `GET ''https://%1$s/hafah-api/market-history/recent-trades?result-limit=1000''`
    operationId: hafah_endpoints.get_recent_trades
    parameters:
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
                "date": "2025-05-26T11:45:57",
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
DROP FUNCTION IF EXISTS hafah_endpoints.get_recent_trades;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_recent_trades(
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
BEGIN
  PERFORM hafah_python.validate_limit("result-limit", 1000, 'result-limit');
  PERFORM hafah_python.validate_negative_limit("result-limit", 'result-limit');

  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN QUERY (
    SELECT
      rt.current_pays,
      rt.date,
      rt.maker,
      rt.open_pays,
      rt.taker
    FROM hafah_backend.recent_trades("result-limit") rt
    ORDER BY rt.date DESC
  );
END
$$
;

RESET ROLE;
