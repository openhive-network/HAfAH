SET ROLE hafah_owner;

/** openapi:paths
/blocks:
  get:
    tags:
      - Blocks
    summary: Get block details in range
    description: |
      Retrieve a range of full, signed blocks.
      The list may be shorter than requested if count blocks would take you past the current head block. 

      SQL example
      * `SELECT * FROM hafah_endpoints.get_block_range(4999999,5000000);`

      REST call example
      * `GET ''https://%1$s/hafah-api/blocks?from-block=4999999&to-block=5000000''`
    operationId: hafah_endpoints.get_block_range
    parameters:
      - in: query
        name: from-block
        required: true
        schema:
          type: string
          default: NULL
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
          default: NULL
        description: | 
          Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). 

          The provided `timestamp` will be converted to a `block-num` by finding the first block 
          where the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).
          
          The function will convert the value depending on its format, example input:

          * `2016-09-15 19:47:21`

          * `5000000`
    responses:
      '200':
        description: |

          * Returns `JSONB`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSONB
            example: [
                  {
                    "witness": "smooth.witness",
                    "block_id": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
                    "previous": "004c4b3e03ea2eac2494790786bfb9e41a8669d9",
                    "timestamp": "2016-09-15T19:47:18",
                    "extensions": [],
                    "signing_key": "STM5jtPaM5G2jemsqTY8xYgy3CVUgzygKn7vUVpFozr6nWcCJ8mDW",
                    "transactions": [
                      {
                        "expiration": "2016-09-15T19:47:27",
                        "extensions": [],
                        "operations": [
                          {
                            "type": "vote_operation",
                            "value": {
                              "voter": "rkpl",
                              "author": "thedevil",
                              "weight": -10000,
                              "permlink": "re-rkpl-how-to-make-a-good-picture-of-the-moon-my-guide-and-photos-20160915t193128824z"
                            }
                          }
                        ],
                        "signatures": [
                          "2046cca841a2c84caf416ccec47f4d894732236505c21964ca092a4bf83b755979402486e49f4f6c116fc7e8d8525df14592d2993365b54ac26cb4bc52d3611e50"
                        ],
                        "ref_block_num": 19245,
                        "ref_block_prefix": 325640405
                      },
                      {
                        "expiration": "2016-09-15T19:47:45",
                        "extensions": [],
                        "operations": [
                          {
                            "type": "limit_order_cancel_operation",
                            "value": {
                              "owner": "cvk",
                              "orderid": 1473968539
                            }
                          }
                        ],
                        "signatures": [
                          "20388171dcf8401b9ca74a79991fa2aaeff26729a28c3acb5510663a930e51f15e180e712e0e7fd3a65b2082ea89583b5155239259fc37c9a0c2b0ec4aacfb6963"
                        ],
                        "ref_block_num": 19262,
                        "ref_block_prefix": 2888755715
                      },
                      {
                        "expiration": "2016-09-15T20:47:15",
                        "extensions": [],
                        "operations": [
                          {
                            "type": "pow2_operation",
                            "value": {
                              "work": {
                                "type": "pow2",
                                "value": {
                                  "input": {
                                    "nonce": "12906882138532220661",
                                    "prev_block": "004c4b3e03ea2eac2494790786bfb9e41a8669d9",
                                    "worker_account": "rabbit-25"
                                  },
                                  "pow_summary": 3818441282
                                }
                              },
                              "props": {
                                "hbd_interest_rate": 1000,
                                "maximum_block_size": 131072,
                                "account_creation_fee": {
                                  "nai": "@@000000021",
                                  "amount": "10000",
                                  "precision": 3
                                }
                              }
                            }
                          }
                        ],
                        "signatures": [
                          "200cecb32d535041c061ea00ec8092c4ab12bf1453035c52987beffb53099f4d5045b29946037b15f9cdde3cbbe0f6e72b8f2f42027cafbeeee54cb8e780f8b07f"
                        ],
                        "ref_block_num": 19262,
                        "ref_block_prefix": 2888755715
                      },
                      {
                        "expiration": "2016-09-15T19:47:45",
                        "extensions": [],
                        "operations": [
                          {
                            "type": "limit_order_cancel_operation",
                            "value": {
                              "owner": "paco-steem",
                              "orderid": 1243424767
                            }
                          }
                        ],
                        "signatures": [
                          "1f7de4d1ea38b5ddb2de499242aacc92d3fff529a74264c568114a48bf4182e4e775bd757cd718cb31b92017279bc781d7282be48abf615aa856bf6828a53b7fe1"
                        ],
                        "ref_block_num": 19262,
                        "ref_block_prefix": 2888755715
                      }
                    ],
                    "transaction_ids": [
                      "9f4639be729f8ca436ac5bd01b5684cbc126d44d",
                      "8f2a70dbe09902473eac39ffbd8ff626cb49bb51",
                      "a9596ee741bd4b4b7d3d8cadd15416bfe854209e",
                      "b664e368d117e0b0d4b1b32325a18044f47b5ca5"
                    ],
                    "witness_signature": "1f4a3e6e868c4b729790e64b0656cf12996f35010dd07b535a502b019080c849c75f370642b00e302d003def5e6b2280246b08ee8ab37824af4664ab740a79b940",
                    "transaction_merkle_root": "708e4d6a2a722ef7fecc58d1f177a2826e54edd3"
                  },
                  {
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
                ]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_block_range;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_block_range(
    "from-block" TEXT = NULL,
    "to-block" TEXT = NULL
)
RETURNS JSONB 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    _block_range hive.blocks_range := hive.convert_to_blocks_range("from-block","to-block");
    __block_num BIGINT = NULL;
    __end_block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  -- Required argument: block-num
  IF _block_range.first_block IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('from-block');
  ELSE
    __block_num = _block_range.first_block::BIGINT;
    IF __block_num < 0 THEN
      __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
    END IF;     
  END IF;

  IF _block_range.last_block IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('to-block');
  ELSE
    __end_block_num = _block_range.last_block::BIGINT;
    IF __end_block_num < 0 THEN
      __end_block_num := __end_block_num + ((POW(2, 31) - 1) :: BIGINT);
    ELSE

    END IF;

  END IF;

  IF _block_range.last_block <= hive.app_get_irreversible_block() AND _block_range.last_block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  BEGIN
    RETURN hafah_python.get_block_range_json(__block_num::INT, __end_block_num::INT);

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
