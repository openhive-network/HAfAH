SET ROLE hafah_owner;

/** openapi
openapi: 3.1.0
info:
  title: HAfAH
  description: >-
    HAfAH It is a web server that responds to account history REST calls.
  license:
    name: MIT License
    url: https://opensource.org/license/mit
  version: 1.27.5
externalDocs:
  description: HAfAH gitlab repository
  url: https://gitlab.syncad.com/hive/hafah
tags:
  - name: Blocks
    description: Informations about blocks
  - name: Transactions
    description: Informations about transactions
  - name: Operations
    description: Informations about operations
  - name: Accounts
    description: Informations about accounts
  - name: Other
    description: General API informations
servers:
  - url: /hafah
 */

DO $__$
DECLARE 
  swagger_url TEXT;
BEGIN
  swagger_url := current_setting('custom.swagger_url')::TEXT;
  
EXECUTE FORMAT(
'create or replace function hafah_endpoints.home() returns json as $_$
declare
-- openapi-spec
-- openapi-generated-code-begin
  openapi json = $$
{
  "openapi": "3.1.0",
  "info": {
    "title": "HAfAH",
    "description": "HAfAH It is a web server that responds to account history REST calls.",
    "license": {
      "name": "MIT License",
      "url": "https://opensource.org/license/mit"
    },
    "version": "1.27.5"
  },
  "externalDocs": {
    "description": "HAfAH gitlab repository",
    "url": "https://gitlab.syncad.com/hive/hafah"
  },
  "tags": [
    {
      "name": "Blocks",
      "description": "Informations about blocks"
    },
    {
      "name": "Transactions",
      "description": "Informations about transactions"
    },
    {
      "name": "Operations",
      "description": "Informations about operations"
    },
    {
      "name": "Accounts",
      "description": "Informations about accounts"
    },
    {
      "name": "Other",
      "description": "General API informations"
    }
  ],
  "servers": [
    {
      "url": "/hafah"
    }
  ],
  "paths": {
    "/blocks": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block details in range",
        "description": "Retrieve a range of full, signed blocks.\nThe list may be shorter than requested if count blocks would take you past the current head block. \n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_range(4999999,5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah/blocks?from-block=4999999&to-block=5000000''`\n",
        "operationId": "hafah_endpoints.get_block_range",
        "parameters": [
          {
            "in": "query",
            "name": "from-block",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "The lower bound for a block''s range"
          },
          {
            "in": "query",
            "name": "to-block",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "The higher bound for a block''s range"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSONB`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSONB"
                },
                "example": [
                  [
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
                ]
              }
            }
          }
        }
      }
    },
    "/blocks/{block-num}": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block details",
        "description": "Retrieve a full, signed block of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block(5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah/blocks/5000000''`\n",
        "operationId": "hafah_endpoints.get_block",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer"
            },
            "description": "Given block number"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSONB`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSONB"
                },
                "example": [
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
              }
            }
          }
        }
      }
    },
    "/blocks/{block-num}/header": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block header of the referenced block",
        "description": "Retrieve a block header of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_header(500000);`\n\nREST call example\n* `GET ''https://%1$s/hafah/blocks/500000/header''`\n",
        "operationId": "hafah_endpoints.get_block_header",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer"
            },
            "description": "Given block number"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSONB`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSONB"
                },
                "example": [
                  {
                    "witness": "ihashfury",
                    "previous": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
                    "timestamp": "2016-09-15T19:47:21",
                    "extensions": [],
                    "transaction_merkle_root": "97a8f2b04848b860f1792dc07bf58efcb15aeb8c"
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/blocks/{block-num}/operations": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get operations in block",
        "description": "Returns all operations contained in a block.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_ops_in_block(5000000);`\n\nREST call example      \n* `GET ''https://%1$s/hafah/blocks/5000000/operations''`\n",
        "operationId": "hafah_endpoints.get_ops_in_block",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Given block number"
          },
          {
            "in": "query",
            "name": "operation-types",
            "required": false,
            "schema": {
              "$ref": "#/components/schemas/hafah_backend.operation_types",
              "default": "all"
            },
            "description": "filter operations by:\n\n * `virtual` - only virtual operations\n\n * `real` - only real operations\n\n * `all` - all operations\n"
          },
          {
            "in": "query",
            "name": "operation-filter-low",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The lower part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "operation-filter-high",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The higher part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "operation-begin",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "BIGINT",
              "default": -1
            },
            "description": "Starting operation id"
          },
          {
            "in": "query",
            "name": "page-size",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "A limit of retrieved operations per page,\nwhen not specified, the result contains all operations in block\n"
          },
          {
            "in": "query",
            "name": "include-reversible",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "If set to true also operations from reversible block will be included\nif block_num points to such block.\n"
          },
          {
            "in": "query",
            "name": "show-legacy-quantities",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "Determines whether to show amounts in legacy style (as `10.000 HIVE`) or use NAI-style"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  {
                    "ops": [
                      {
                        "op": {
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
                        },
                        "block": 5000000,
                        "trx_id": "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                        "op_in_trx": 0,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": false,
                        "operation_id": "21474836480000009",
                        "trx_in_block": 0
                      },
                      {
                        "op": {
                          "type": "account_created_operation",
                          "value": {
                            "creator": "steem",
                            "new_account_name": "kefadex",
                            "initial_delegation": {
                              "nai": "@@000000037",
                              "amount": "0",
                              "precision": 6
                            },
                            "initial_vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "30038455132",
                              "precision": 6
                            }
                          }
                        },
                        "block": 5000000,
                        "trx_id": "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": true,
                        "operation_id": "21474836480000336",
                        "trx_in_block": 0
                      },
                      {
                        "op": {
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
                        },
                        "block": 5000000,
                        "trx_id": "973290d26bac31335c000c7a3d3fe058ce3dbb9f",
                        "op_in_trx": 0,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": false,
                        "operation_id": "21474836480000517",
                        "trx_in_block": 1
                      },
                      {
                        "op": {
                          "type": "producer_reward_operation",
                          "value": {
                            "producer": "ihashfury",
                            "vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "3003845513",
                              "precision": 6
                            }
                          }
                        },
                        "block": 5000000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": true,
                        "operation_id": "21474836480000832",
                        "trx_in_block": 4294967295
                      }
                    ],
                    "next_operation_begin": 0
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/operations": {
      "get": {
        "tags": [
          "Operations"
        ],
        "summary": "Get operations in block range",
        "description": "Returns all operations contained in provided block range\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_operations(4999999,5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah/operations?from-block=4999999&to-block=5000000&operation-types=virtual''`\n",
        "operationId": "hafah_endpoints.get_operations",
        "parameters": [
          {
            "in": "query",
            "name": "from-block",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": null
          },
          {
            "in": "query",
            "name": "to-block",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "The distance between the blocks can be a maximum of 2000"
          },
          {
            "in": "query",
            "name": "operation-types",
            "required": false,
            "schema": {
              "$ref": "#/components/schemas/hafah_backend.operation_types",
              "default": "all"
            },
            "description": "filter operations by:\n\n * `virtual` - only virtual operations\n\n * `real` - only real operations\n\n * `all` - all operations\n"
          },
          {
            "in": "query",
            "name": "operation-filter-low",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The lower part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "operation-filter-high",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The higher part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "operation-begin",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "BIGINT",
              "default": -1
            },
            "description": "Starting operation id"
          },
          {
            "in": "query",
            "name": "page-size",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1000
            },
            "description": "A limit of retrieved operations per page,\nup to 150000\n"
          },
          {
            "in": "query",
            "name": "include-reversible",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "If set to true also operations from reversible block will be included\nif block_num points to such block.\n"
          },
          {
            "in": "query",
            "name": "show-legacy-quantities",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "Determines whether to show amounts in legacy style (as `10.000 HIVE`) or use NAI-style"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  {
                    "ops": [
                      {
                        "op": {
                          "type": "effective_comment_vote_operation",
                          "value": {
                            "voter": "rkpl",
                            "author": "thedevil",
                            "weight": 0,
                            "rshares": -1383373254,
                            "permlink": "re-rkpl-how-to-make-a-good-picture-of-the-moon-my-guide-and-photos-20160915t193128824z",
                            "pending_payout": {
                              "nai": "@@000000013",
                              "amount": "0",
                              "precision": 3
                            },
                            "total_vote_weight": 590910411298246
                          }
                        },
                        "block": 4999999,
                        "trx_id": "9f4639be729f8ca436ac5bd01b5684cbc126d44d",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:18",
                        "virtual_op": true,
                        "operation_id": "21474832185033032",
                        "trx_in_block": 0
                      },
                      {
                        "op": {
                          "type": "limit_order_cancelled_operation",
                          "value": {
                            "seller": "cvk",
                            "orderid": 1473968539,
                            "amount_back": {
                              "nai": "@@000000021",
                              "amount": "9941",
                              "precision": 3
                            }
                          }
                        },
                        "block": 4999999,
                        "trx_id": "8f2a70dbe09902473eac39ffbd8ff626cb49bb51",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:18",
                        "virtual_op": true,
                        "operation_id": "21474832185033557",
                        "trx_in_block": 1
                      },
                      {
                        "op": {
                          "type": "pow_reward_operation",
                          "value": {
                            "reward": {
                              "nai": "@@000000037",
                              "amount": "5031442145",
                              "precision": 6
                            },
                            "worker": "smooth.witness"
                          }
                        },
                        "block": 4999999,
                        "trx_id": "a9596ee741bd4b4b7d3d8cadd15416bfe854209e",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:18",
                        "virtual_op": true,
                        "operation_id": "21474832185034062",
                        "trx_in_block": 2
                      },
                      {
                        "op": {
                          "type": "limit_order_cancelled_operation",
                          "value": {
                            "seller": "paco-steem",
                            "orderid": 1243424767,
                            "amount_back": {
                              "nai": "@@000000013",
                              "amount": "19276",
                              "precision": 3
                            }
                          }
                        },
                        "block": 4999999,
                        "trx_id": "b664e368d117e0b0d4b1b32325a18044f47b5ca5",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:18",
                        "virtual_op": true,
                        "operation_id": "21474832185034581",
                        "trx_in_block": 3
                      },
                      {
                        "op": {
                          "type": "producer_reward_operation",
                          "value": {
                            "producer": "smooth.witness",
                            "vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "3003846056",
                              "precision": 6
                            }
                          }
                        },
                        "block": 4999999,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:18",
                        "virtual_op": true,
                        "operation_id": "21474832185034816",
                        "trx_in_block": 4294967295
                      },
                      {
                        "op": {
                          "type": "account_created_operation",
                          "value": {
                            "creator": "steem",
                            "new_account_name": "kefadex",
                            "initial_delegation": {
                              "nai": "@@000000037",
                              "amount": "0",
                              "precision": 6
                            },
                            "initial_vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "30038455132",
                              "precision": 6
                            }
                          }
                        },
                        "block": 5000000,
                        "trx_id": "6707feb450da66dc223ab5cb3e259937b2fef6bf",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": true,
                        "operation_id": "21474836480000336",
                        "trx_in_block": 0
                      },
                      {
                        "op": {
                          "type": "producer_reward_operation",
                          "value": {
                            "producer": "ihashfury",
                            "vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "3003845513",
                              "precision": 6
                            }
                          }
                        },
                        "block": 5000000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": true,
                        "operation_id": "21474836480000832",
                        "trx_in_block": 4294967295
                      }
                    ],
                    "next_operation_begin": 0,
                    "next_block_range_begin": 5000000
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/transactions/{transaction-id}": {
      "get": {
        "tags": [
          "Transactions"
        ],
        "summary": "Get transaction details",
        "description": "Returns the details of a transaction based on a transaction id (including their signatures,\noperations like also a block_num it was included to).\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_transaction(''954f6de36e6715d128fa8eb5a053fc254b05ded0'');`\n\nREST call example\n* `GET ''https://%1$s/hafah/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0''`\n",
        "operationId": "hafah_endpoints.get_transaction",
        "parameters": [
          {
            "in": "path",
            "name": "transaction-id",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "trx_id of expected transaction\n"
          },
          {
            "in": "query",
            "name": "include-reversible",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "If set to true also operations from reversible block will be included\nif block_num points to such block.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  {
                    "ref_block_num": 25532,
                    "ref_block_prefix": 3338687976,
                    "extensions": [],
                    "expiration": "2016-08-12T17:23:48",
                    "operations": [
                      {
                        "type": "custom_json_operation",
                        "value": {
                          "id": "follow",
                          "json": "{\"follower\":\"breck0882\",\"following\":\"steemship\",\"what\":[]}",
                          "required_auths": [],
                          "required_posting_auths": [
                            "breck0882"
                          ]
                        }
                      }
                    ],
                    "signatures": [
                      "201655190aac43bb272185c577262796c57e5dd654e3e491b9b32bd2d567c6d5de75185f221a38697d04d1a8e6a9deb722ec6d6b5d2f395dcfbb94f0e5898e858f"
                    ],
                    "transaction_id": "954f6de36e6715d128fa8eb5a053fc254b05ded0",
                    "block_num": 4023233,
                    "transaction_num": 0
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/accounts/{account-name}/operations": {
      "get": {
        "tags": [
          "Accounts"
        ],
        "summary": "Get account''s history",
        "description": "Returns a history of all operations for a given account.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_account_history(''blocktrades'');`\n\nREST call example\n* `GET ''https://%1$s/hafah/accounts/blocktrades/operations?result-limit=3''`\n",
        "operationId": "hafah_endpoints.get_account_history",
        "parameters": [
          {
            "in": "path",
            "name": "account-name",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "given account name"
          },
          {
            "in": "query",
            "name": "start",
            "required": false,
            "schema": {
              "type": "integer",
              "default": -1
            },
            "description": "e.g.: -1 for reverse history or any positive numeric\n"
          },
          {
            "in": "query",
            "name": "result-limit",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1000
            },
            "description": "up to 1000"
          },
          {
            "in": "query",
            "name": "include-reversible",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "If set to true also operations from reversible block will be included\n"
          },
          {
            "in": "query",
            "name": "operation-filter-low",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The lower part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "operation-filter-high",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "NUMERIC",
              "default": null
            },
            "description": "The higher part of the bits of a 128-bit integer mask,\nwhere successive positions of bits set to 1 define which operation type numbers to return,\nexpressed as a decimal number\n"
          },
          {
            "in": "query",
            "name": "show-legacy-quantities",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "Determines whether to show amounts in legacy style (as `10.000 HIVE`) or use NAI-style"
          }
        ],
        "responses": {
          "200": {
            "description": "\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  [
                    [
                      219864,
                      {
                        "op": {
                          "type": "producer_reward_operation",
                          "value": {
                            "producer": "blocktrades",
                            "vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "3003868105",
                              "precision": 6
                            }
                          }
                        },
                        "block": 4999959,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:45:12",
                        "virtual_op": true,
                        "operation_id": "21474660386343488",
                        "trx_in_block": 4294967295
                      }
                    ],
                    [
                      219865,
                      {
                        "op": {
                          "type": "producer_reward_operation",
                          "value": {
                            "producer": "blocktrades",
                            "vesting_shares": {
                              "nai": "@@000000037",
                              "amount": "3003850165",
                              "precision": 6
                            }
                          }
                        },
                        "block": 4999992,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-09-15T19:46:57",
                        "virtual_op": true,
                        "operation_id": "21474802120262208",
                        "trx_in_block": 4294967295
                      }
                    ],
                    [
                      219866,
                      {
                        "op": {
                          "type": "transfer_operation",
                          "value": {
                            "to": "blocktrades",
                            "from": "mrwang",
                            "memo": "a79c09cd-0084-4cd4-ae63-bf6d2514fef9",
                            "amount": {
                              "nai": "@@000000013",
                              "amount": "1633",
                              "precision": 3
                            }
                          }
                        },
                        "block": 4999997,
                        "trx_id": "e75f833ceb62570c25504b55d0f23d86d9d76423",
                        "op_in_trx": 0,
                        "timestamp": "2016-09-15T19:47:12",
                        "virtual_op": false,
                        "operation_id": "21474823595099394",
                        "trx_in_block": 3
                      }
                    ]
                  ]
                ]
              }
            }
          }
        }
      }
    },
    "/version": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "hafah''s version",
        "description": "Get hafah''s last commit hash that determinates its version\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_version();`\n\nREST call example\n* `GET ''https://%1$s/hafah/version''`\n",
        "operationId": "hafah_endpoints.get_version",
        "responses": {
          "200": {
            "description": "\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": "c2fed8958584511ef1a66dab3dbac8c40f3518f0"
              }
            }
          },
          "404": {
            "description": "App not installed"
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "hafah_backend.operation_types": {
        "type": "string",
        "enum": [
          "virtual",
          "real",
          "all"
        ]
      }
    }
  }
}
$$;
-- openapi-generated-code-end
begin
  return openapi;
end
$_$ language plpgsql;'
, swagger_url);

END
$__$;

RESET ROLE;
