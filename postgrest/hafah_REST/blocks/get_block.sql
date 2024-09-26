SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}:
  get:
    tags:
      - Blocks
    summary: Get block details
    description: |
      Retrieve a full, signed block of the referenced block, or null if no matching block was found.

      SQL example
      * `SELECT * FROM hafah_endpoints.get_block(5000000);`

      REST call example
      * `GET ''https://%1$s/hafah-api/blocks/5000000''`
    operationId: hafah_endpoints.get_block
    parameters: 
      - in: path
        name: block-num
        required: true
        schema:
          type: string
        description: |
          Given block, can be represented either by a `block-num` (integer) or a `timestamp` (in the format `YYYY-MM-DD HH:MI:SS`),

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`). 
        
          The function will interpret and convert the input based on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
      - in: query
        name: include-virtual
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If true, virtual operations will be included.
    responses:
      '200':
        description: |

          * Returns `JSONB`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSONB
            example: 
              - {
                  "witness": "ihashfury",
                  "block_id": "004c4b40245ffb07380a393fb2b3d841b76cdaec",
                  "previous": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
                  "timestamp": "2016-09-15T19:47:21",
                  "extensions": [],
                  "signing_key": "STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2",
                  "transactions": [
                    {
                      "expiration": "2016-09-15T19:47:33",
                      "extensions": [],
                      "operations": [
                        {
                          "type": "account_create_operation",
                          "value": {
                            "fee": {
                              "nai": "@@000000021",
                              "amount": "10000",
                              "precision": 3
                            },
                            "owner": {
                              "key_auths": [
                                [
                                  "STM871wj5KKnbwwiRv3scVcxQ26ynPnE1uaZr6dPpqVu9F4zJZgjZ",
                                  1
                                ]
                              ],
                              "account_auths": [],
                              "weight_threshold": 1
                            },
                            "active": {
                              "key_auths": [
                                [
                                  "STM73bAnWEwkdUa7Lp4ovNzyu4soHUCaCNSz79YHQsDqscNdSe1E8",
                                  1
                                ]
                              ],
                              "account_auths": [],
                              "weight_threshold": 1
                            },
                            "creator": "steem",
                            "posting": {
                              "key_auths": [
                                [
                                  "STM7fXKrnQN3xhgFTQBFMgR9TU8CxfgAJrLvSDjGuM2bFkiuKfwZg",
                                  1
                                ]
                              ],
                              "account_auths": [],
                              "weight_threshold": 1
                            },
                            "memo_key": "STM8i93Zznxu2QRNLCHBDXt5yyiMW1c3GEyVKV9XAs8H5wEWwdJaM",
                            "json_metadata": "",
                            "new_account_name": "kefadex"
                          }
                        }
                      ],
                      "signatures": [
                        "1f63c75cc966916ea705a6fdef0821a810bdabb07118a3721f4cd52c972b9e4522534248c45ac908c1498752165a1d937eaf55ab6c028d7ee0ad893d3d4330d066"
                      ],
                      "ref_block_num": 19263,
                      "ref_block_prefix": 1534306502
                    },
                    {
                      "expiration": "2016-09-15T19:47:48",
                      "extensions": [],
                      "operations": [
                        {
                          "type": "limit_order_create_operation",
                          "value": {
                            "owner": "cvk",
                            "orderid": 1473968838,
                            "expiration": "2035-10-29T06:32:22",
                            "fill_or_kill": false,
                            "amount_to_sell": {
                              "nai": "@@000000021",
                              "amount": "10324",
                              "precision": 3
                            },
                            "min_to_receive": {
                              "nai": "@@000000013",
                              "amount": "6819",
                              "precision": 3
                            }
                          }
                        }
                      ],
                      "signatures": [
                        "203e8ef6d16005180dc06756462bd867513a929bc4fa7c45f24ca2b0763cafdb06678812d777216f46d205e68a740dd19e32a1aa1a1df022500c0f1ef97800d0e0"
                      ],
                      "ref_block_num": 19263,
                      "ref_block_prefix": 1534306502
                    }
                  ],
                  "transaction_ids": [
                    "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                    "973290d26bac31335c000c7a3d3fe058ce3dbb9f"
                  ],
                  "witness_signature": "1f6aa1c6311c768b5225b115eaf5798e5f1d8338af3970d90899cd5ccbe38f6d1f7676c5649bcca18150cbf8f07c0cc7ec3ae40d5936cfc6d5a650e582ba0f8002",
                  "transaction_merkle_root": "97a8f2b04848b860f1792dc07bf58efcb15aeb8c"
                }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_block;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_block(
    "block-num" TEXT,
    "include-virtual" BOOLEAN = False
)
RETURNS JSONB 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __block INT := hive.convert_to_block_num("block-num");
    __block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
    -- Required argument: block-num
  IF __block IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('block-num');
  ELSE
      __block_num = __block::BIGINT;
      IF __block_num < 0 THEN
          __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
      END IF;        
  END IF;

  IF __block <= hive.app_get_irreversible_block() AND __block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  BEGIN
    RETURN hafah_python.get_block_json(__block_num::INT, "include-virtual");

    EXCEPTION
      WHEN invalid_text_representation THEN
        RETURN hafah_backend.rest_raise_uint_exception();
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message);
  END;
END
$$
;

RESET ROLE;
