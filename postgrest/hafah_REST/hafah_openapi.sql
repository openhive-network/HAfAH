SET ROLE hafah_owner;

/** openapi
openapi: 3.1.0
info:
  title: HAfAH
  description: >-
    HAfAH A web server that responds to account history REST calls.
  license:
    name: MIT License
    url: https://opensource.org/license/mit
  version: 1.27.5
externalDocs:
  description: HAfAH gitlab repository
  url: https://gitlab.syncad.com/hive/hafah
tags:
  - name: Blocks
    description: Information about blocks
  - name: Transactions
    description: Information about transactions
  - name: Operations
    description: Information about operations
  - name: Operation-types
    description: Informatios about operation types
  - name: Accounts
    description: Information about accounts
  - name: Other
    description: General API information
servers:
  - url: /hafah-api
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
  "components": {
    "schemas": {
      "hafah_backend.op_types": {
        "type": "object",
        "properties": {
          "op_type_id": {
            "type": "integer",
            "description": "operation type id"
          },
          "operation_name": {
            "type": "string",
            "description": "operation type name"
          },
          "is_virtual": {
            "type": "boolean",
            "description": "true if operation is virtual"
          }
        }
      },
      "hafah_backend.operation_group_types": {
        "type": "string",
        "enum": [
          "virtual",
          "real",
          "all"
        ]
      },
      "hafah_backend.operation": {
        "type": "object",
        "properties": {
          "op": {
            "type": "string",
            "x-sql-datatype": "JSONB",
            "description": "operation body"
          },
          "block": {
            "type": "integer",
            "description": "block containing the operation"
          },
          "trx_id": {
            "type": "string",
            "description": "hash of the transaction"
          },
          "op_pos": {
            "type": "integer",
            "description": "operation identifier that indicates its sequence number in transaction"
          },
          "op_type_id": {
            "type": "integer",
            "description": "operation type identifier"
          },
          "timestamp": {
            "type": "string",
            "format": "date-time",
            "description": "creation date"
          },
          "virtual_op": {
            "type": "boolean",
            "description": "true if is a virtual operation"
          },
          "operation_id": {
            "type": "string",
            "description": "unique operation identifier with an encoded block number and operation type id"
          },
          "trx_in_block": {
            "type": "integer",
            "x-sql-datatype": "SMALLINT",
            "description": "transaction identifier that indicates its sequence number in block"
          }
        }
      },
      "hafah_backend.sort_direction": {
        "type": "string",
        "enum": [
          "asc",
          "desc"
        ]
      },
      "hafah_backend.block": {
        "type": "object",
        "properties": {
          "block_num": {
            "type": "integer",
            "description": "block number"
          },
          "hash": {
            "type": "string",
            "description": "block hash in a blockchain is a unique, fixed-length string generated  by applying a cryptographic hash function to a block''s contents"
          },
          "prev": {
            "type": "string",
            "description": "hash of a previous block"
          },
          "producer_account": {
            "type": "string",
            "description": "account name of block''s producer"
          },
          "transaction_merkle_root": {
            "type": "string",
            "description": "single hash representing the combined hashes of all transactions in a block"
          },
          "extensions": {
            "type": "string",
            "x-sql-datatype": "JSONB",
            "description": "various additional data/parameters related to the subject at hand. Most often, there''s nothing specific, but it''s a mechanism for extending various functionalities where something might appear in the future."
          },
          "witness_signature": {
            "type": "string",
            "description": "witness signature"
          },
          "signing_key": {
            "type": "string",
            "description": "it refers to the public key of the witness used for signing blocks and other witness operations"
          },
          "hbd_interest_rate": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the interest rate on HBD in savings, expressed in basis points (previously for each HBD), is one of the values determined by the witnesses"
          },
          "total_vesting_fund_hive": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the balance of the \"counterweight\" for these VESTS (total_vesting_shares) in the form of HIVE  (the price of VESTS is derived from these two values). A portion of the inflation is added to the balance, ensuring that each block corresponds to more HIVE for the VESTS"
          },
          "total_vesting_shares": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the total amount of VEST present in the system"
          },
          "total_reward_fund_hive": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "deprecated after HF17"
          },
          "virtual_supply": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the total amount of HIVE, including the HIVE that would be generated from converting HBD to HIVE at the current price"
          },
          "current_supply": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the total amount of HIVE present in the system"
          },
          "current_hbd_supply": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the total amount of HBD present in the system, including what is in the treasury"
          },
          "dhf_interval_ledger": {
            "type": "number",
            "x-sql-datatype": "numeric",
            "description": "the dhf_interval_ledger is a temporary HBD balance. Each block allocates a portion of inflation for proposal payouts, but these payouts occur every hour. To avoid cluttering the history with small amounts each block,  the new funds are first accumulated in the dhf_interval_ledger. Then, every HIVE_PROPOSAL_MAINTENANCE_PERIOD, the accumulated funds are transferred to the treasury account (this operation generates the virtual operation dhf_funding_operation), from where they are subsequently paid out to the approved proposals"
          },
          "created_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp when the block was created"
          }
        }
      },
      "hafah_backend.array_of_op_types": {
        "type": "array",
        "items": {
          "$ref": "#/components/schemas/hafah_backend.op_types"
        }
      },
      "hafah_endpoints.transaction": {
        "type": "object",
        "properties": {
          "transaction_json": {
            "type": "string",
            "x-sql-datatype": "JSON",
            "description": "contents of the transaction"
          },
          "transaction_id": {
            "type": "string",
            "description": "hash of the transaction"
          },
          "block_num": {
            "type": "integer",
            "description": "block containing the transaction"
          },
          "transaction_num": {
            "type": "integer",
            "description": "number of transactions in the block"
          },
          "timestamp": {
            "type": "string",
            "format": "date-time",
            "description": "time transaction was inlcuded in block"
          }
        }
      }
    }
  },
  "openapi": "3.1.0",
  "info": {
    "title": "HAfAH",
    "description": "HAfAH A web server that responds to account history REST calls.",
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
      "description": "Information about blocks"
    },
    {
      "name": "Transactions",
      "description": "Information about transactions"
    },
    {
      "name": "Operations",
      "description": "Information about operations"
    },
    {
      "name": "Operation-types",
      "description": "Informatios about operation types"
    },
    {
      "name": "Accounts",
      "description": "Information about accounts"
    },
    {
      "name": "Other",
      "description": "General API information"
    }
  ],
  "servers": [
    {
      "url": "/hafah-api"
    }
  ],
  "paths": {
    "/blocks": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block details in range",
        "description": "Retrieve a range of full, signed blocks.\nThe list may be shorter than requested if count blocks would take you past the current head block. \n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_range(4999999,5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/blocks?from-block=4999999&to-block=5000000''`\n",
        "operationId": "hafah_endpoints.get_block_range",
        "parameters": [
          {
            "in": "query",
            "name": "from-block",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Lower limit of the block range, can be represented either by a block-number (integer) or a timestamp (in the format YYYY-MM-DD HH:MI:SS).\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is more than or equal to the given `timestamp` (i.e. `block''s created_at >= timestamp`).\n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          },
          {
            "in": "query",
            "name": "to-block",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). \n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).\n\nThe function will convert the value depending on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
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
        "description": "Retrieve a full, signed block of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block(5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/blocks/5000000''`\n",
        "operationId": "hafah_endpoints.get_block",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Given block, can be represented either by a `block-num` (integer) or a `timestamp` (in the format `YYYY-MM-DD HH:MI:SS`),\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`). \n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
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
        "description": "Retrieve a block header of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_header(500000);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/blocks/500000/header''`\n",
        "operationId": "hafah_endpoints.get_block_header",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Given block, can be represented either by a `block-num` (integer) or a `timestamp` (in the format `YYYY-MM-DD HH:MI:SS`),\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`). \n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
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
        "description": "List the operations in the specified order that are within the given block number. \nThe page size determines the number of operations per page\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_ops_by_block_paging(5000000,''5,64'');`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/blocks/5000000/operations?operation-types=80&path-filter=value.creator=steem''`\n",
        "operationId": "hafah_endpoints.get_ops_by_block_paging",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Given block, can be represented either by a `block-num` (integer) or a `timestamp` (in the format `YYYY-MM-DD HH:MI:SS`),\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`). \n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          },
          {
            "in": "query",
            "name": "operation-types",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "List of operations: if the parameter is empty, all operations will be included,\nexample: `18,12`\n"
          },
          {
            "in": "query",
            "name": "account-name",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Filter operations by the account that created them"
          },
          {
            "in": "query",
            "name": "page",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": "Return page on `page` number, defaults to `1`"
          },
          {
            "in": "query",
            "name": "page-size",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 100
            },
            "description": "Return max `page-size` operations per page, defaults to `100`"
          },
          {
            "in": "query",
            "name": "page-order",
            "required": false,
            "schema": {
              "$ref": "#/components/schemas/hafah_backend.sort_direction",
              "default": "desc"
            },
            "description": "page order:\n\n * `asc` - Ascending, from oldest to newest page\n \n * `desc` - Descending, from newest to oldest page\n"
          },
          {
            "in": "query",
            "name": "data-size-limit",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 200000
            },
            "description": "If the operation length exceeds the data size limit,\nthe operation body is replaced with a placeholder, defaults to `200000`\n"
          },
          {
            "in": "query",
            "name": "path-filter",
            "required": false,
            "schema": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "x-sql-datatype": "TEXT[]",
              "default": null
            },
            "description": "A parameter specifying the expected value in operation body,\nexample: `value.creator=steem`\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Result contains total operations number,\ntotal pages and the list of operations\n\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  {
                    "total_operations": 1,
                    "total_pages": 1,
                    "operations_result": [
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
                        "op_pos": 1,
                        "op_type_id": 80,
                        "timestamp": "2016-09-15T19:47:21",
                        "virtual_op": true,
                        "operation_id": "21474836480000336",
                        "trx_in_block": 0
                      }
                    ]
                  }
                ]
              }
            }
          },
          "404": {
            "description": "The result is empty"
          }
        }
      }
    },
    "/operations": {
      "get": {
        "tags": [
          "Operations"
        ],
        "summary": "Get operations in a block range",
        "description": "Returns all operations contained in specified block range, supports various forms of filtering.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_operations(4999999,5000000);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/operations?from-block=4999999&to-block=5000000&operation-group-type=virtual''`\n",
        "operationId": "hafah_endpoints.get_operations",
        "parameters": [
          {
            "in": "query",
            "name": "from-block",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Lower limit of the block range, can be represented either by a block-number (integer) or a timestamp (in the format YYYY-MM-DD HH:MI:SS).\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is more than or equal to the given `timestamp` (i.e. `block''s created_at >= timestamp`).\n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          },
          {
            "in": "query",
            "name": "to-block",
            "required": true,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). \n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).\n\nThe function will convert the value depending on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          },
          {
            "in": "query",
            "name": "operation-types",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "List of operations: if the parameter is empty, all operations will be included.\nexample: `18,12`\n"
          },
          {
            "in": "query",
            "name": "operation-group-type",
            "required": false,
            "schema": {
              "$ref": "#/components/schemas/hafah_backend.operation_group_types",
              "default": "all"
            },
            "description": "filter operations by:\n\n * `virtual` - only virtual operations\n\n * `real` - only real operations\n\n * `all` - all operations\n"
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
            "description": "If true, operations from reversible blocks will be included.\n"
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
    "/operations/{operation-id}": {
      "get": {
        "tags": [
          "Operations"
        ],
        "summary": "lookup an operation by its id.",
        "description": "Get operation''s body and its extended parameters\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_operation(3448858738752);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/operations/3448858738752''`\n",
        "operationId": "hafah_endpoints.get_operation",
        "parameters": [
          {
            "in": "path",
            "name": "operation-id",
            "required": true,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "BIGINT"
            },
            "description": "An operation-id is a unique operation identifier,\nencodes three key pieces of information into a single number,\nwith each piece occupying a specific number of bits:\n\n```\nmsb.....................lsb\n || block | op_pos | type ||\n ||  32b  |  24b   |  8b  ||\n```\n\n * block (block number) - occupies 32 bits.\n\n * op_pos (position of an operation in block) - occupies 24 bits.\n\n * type (operation type) - occupies 8 bits.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Operation parameters\n\n* Returns `hafah_backend.operation`\n",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/hafah_backend.operation"
                },
                "example": [
                  {
                    "op": {
                      "type": "producer_reward_operation",
                      "value": {
                        "producer": "initminer",
                        "vesting_shares": {
                          "nai": "@@000000021",
                          "amount": "1000",
                          "precision": 3
                        }
                      }
                    },
                    "block": 803,
                    "trx_id": null,
                    "op_pos": 1,
                    "timestamp": "2016-03-24T16:45:39",
                    "virtual_op": true,
                    "operation_id": "3448858738752",
                    "trx_in_block": -1
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/operation-types": {
      "get": {
        "tags": [
          "Operation-types"
        ],
        "summary": "Lookup operation type ids for operations matching a partial operation name.",
        "description": "Lookup operation type ids for operations matching a partial operation name.\n\nSQL example  \n* `SELECT * FROM hafah_endpoints.get_op_types(''author'');`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/operation-types?partial-operation-name=author''`\n",
        "operationId": "hafah_endpoints.get_op_types",
        "parameters": [
          {
            "in": "query",
            "name": "partial-operation-name",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "parial name of operation"
          }
        ],
        "responses": {
          "200": {
            "description": "Operation type list, \nif `partial-operation-name` is provided then the list\nis limited to operations that partially match the `partial-operation-name`\n\n* Returns array of `hafah_backend.op_types`\n",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/hafah_backend.array_of_op_types"
                },
                "example": [
                  {
                    "op_type_id": 51,
                    "operation_name": "author_reward_operation",
                    "is_virtual": true
                  }
                ]
              }
            }
          },
          "404": {
            "description": "No operations in the database"
          }
        }
      }
    },
    "/operation-types/{type-id}/keys": {
      "get": {
        "tags": [
          "Operation-types"
        ],
        "summary": "Returns key names for an operation type.",
        "description": "Returns json body keys for an operation type\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_operation_keys(1);`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/operation-types/1/keys''`\n",
        "operationId": "hafah_endpoints.get_operation_keys",
        "parameters": [
          {
            "in": "path",
            "name": "type-id",
            "required": true,
            "schema": {
              "type": "integer"
            },
            "description": "Unique operation type identifier"
          }
        ],
        "responses": {
          "200": {
            "description": "Operation json key paths\n\n* Returns `JSONB`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSONB"
                },
                "example": [
                  [
                    [
                      "value",
                      "body"
                    ],
                    [
                      "value",
                      "title"
                    ],
                    [
                      "value",
                      "author"
                    ],
                    [
                      "value",
                      "permlink"
                    ],
                    [
                      "value",
                      "json_metadata"
                    ],
                    [
                      "value",
                      "parent_author"
                    ],
                    [
                      "value",
                      "parent_permlink"
                    ]
                  ]
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
        "summary": "Lookup a transaction''s details from its transaction id.",
        "description": "Returns the details of a transaction based on a transaction id (including its signatures,\noperations, and containing block number).\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_transaction(''954f6de36e6715d128fa8eb5a053fc254b05ded0'');`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0''`\n",
        "operationId": "hafah_endpoints.get_transaction",
        "parameters": [
          {
            "in": "path",
            "name": "transaction-id",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "transaction id of transaction to look up"
          }
        ],
        "responses": {
          "200": {
            "description": "The transaction body\n\n* Returns `hafah_endpoints.transaction`\n",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/hafah_endpoints.transaction"
                },
                "example": [
                  {
                    "transaction_json": {
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
                        "201655190aac43bb272185c577262796c57e5dd654e3e491b921a38697d04d1a8e6a9deb722ec6d6b5d2f395dcfbb94f0e5898e858f"
                      ]
                    },
                    "transaction_id": "954f6de36e6715d128fa8eb5a053fc254b05ded0",
                    "block_num": 4023233,
                    "transaction_num": 0,
                    "timestamp": "2016-08-12T17:23:39"
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
        "summary": "Get operations for an account by recency.",
        "description": "List the operations in reversed order (first page is the oldest) for given account. \nThe page size determines the number of operations per page.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_ops_by_account(''blocktrades'');`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/accounts/blocktrades/operations?page-size=3''`\n",
        "operationId": "hafah_endpoints.get_ops_by_account",
        "parameters": [
          {
            "in": "path",
            "name": "account-name",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Account to get operations for."
          },
          {
            "in": "query",
            "name": "operation-types",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "List of operation types to get. If NULL, gets all operation types.\nexample: `18,12`\n"
          },
          {
            "in": "query",
            "name": "page",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Return page on `page` number, default null due to reversed order of pages,\nthe first page is the oldest,\nexample: first call returns the newest page and total_pages is 100 - the newest page is number 100, next 99 etc.\n"
          },
          {
            "in": "query",
            "name": "page-size",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 100
            },
            "description": "Return max `page-size` operations per page, defaults to `100`."
          },
          {
            "in": "query",
            "name": "data-size-limit",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 200000
            },
            "description": "If the operation length exceeds the data size limit,\nthe operation body is replaced with a placeholder (defaults to `200000`).\n"
          },
          {
            "in": "query",
            "name": "from-block",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Lower limit of the block range, can be represented either by a block-number (integer) or a timestamp (in the format YYYY-MM-DD HH:MI:SS).\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is more than or equal to the given `timestamp` (i.e. `block''s created_at >= timestamp`).\n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          },
          {
            "in": "query",
            "name": "to-block",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Similar to the from-block parameter, can either be a block-number (integer) or a timestamp (formatted as YYYY-MM-DD HH:MI:SS). \n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`).\n\nThe function will convert the value depending on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Result contains total number of operations,\ntotal pages, and the list of operations.\n\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSON"
                },
                "example": [
                  {
                    "total_operations": 219867,
                    "total_pages": 73289,
                    "operations_result": [
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
                        "op_pos": 0,
                        "op_type_id": 2,
                        "timestamp": "2016-09-15T19:47:12",
                        "virtual_op": false,
                        "operation_id": "21474823595099394",
                        "trx_in_block": 3
                      },
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
                        "trx_id": null,
                        "op_pos": 1,
                        "op_type_id": 64,
                        "timestamp": "2016-09-15T19:46:57",
                        "virtual_op": true,
                        "operation_id": "21474802120262208",
                        "trx_in_block": -1
                      },
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
                        "trx_id": null,
                        "op_pos": 1,
                        "op_type_id": 64,
                        "timestamp": "2016-09-15T19:45:12",
                        "virtual_op": true,
                        "operation_id": "21474660386343488",
                        "trx_in_block": -1
                      }
                    ]
                  }
                ]
              }
            }
          },
          "404": {
            "description": "No such account in the database"
          }
        }
      }
    },
    "/accounts/{account-name}/operation-types": {
      "get": {
        "tags": [
          "Accounts"
        ],
        "summary": "Lists all types of operations that account has performed",
        "description": "Lists all types of operations that the account has performed since its creation\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_acc_op_types(''blocktrades'');`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/accounts/blocktrades/operations/types''`\n",
        "operationId": "hafah_endpoints.get_acc_op_types",
        "parameters": [
          {
            "in": "path",
            "name": "account-name",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Name of the account"
          }
        ],
        "responses": {
          "200": {
            "description": "Operation type list\n\n* Returns `JSONB`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "x-sql-datatype": "JSONB"
                },
                "example": [
                  [
                    0,
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    10,
                    11,
                    12,
                    13,
                    14,
                    15,
                    18,
                    20,
                    51,
                    52,
                    53,
                    55,
                    56,
                    57,
                    61,
                    64,
                    72,
                    77,
                    78,
                    79,
                    80,
                    85,
                    86
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
        "description": "Get hafah''s last commit hash (hash is used for versioning).\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_version();`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/version''`\n",
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
    },
    "/headblock": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "Get last synced block in the HAF database.",
        "description": "Get last synced block in the HAF database\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_head_block_num();`\n\nREST call example\n* `GET ''https://%1$s/hafah-api/headblock''`\n",
        "operationId": "hafah_endpoints.get_head_block_num",
        "responses": {
          "200": {
            "description": "Last block stored in HAF\n\n* Returns `INT`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "integer"
                },
                "example": 5000000
              }
            }
          },
          "404": {
            "description": "No blocks in the database"
          }
        }
      }
    },
    "/global-state": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "Reports global state information at the given block.",
        "description": "Reports dgpo-style data for a given block.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_global_state(5000000);`\n\nREST call example      \n* `GET ''https://%1$s/hafah-api/global-state?block-num=5000000''`\n",
        "operationId": "hafah_endpoints.get_global_state",
        "parameters": [
          {
            "in": "query",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Given block, can be represented either by a `block-num` (integer) or a `timestamp` (in the format `YYYY-MM-DD HH:MI:SS`),\n\nThe provided `timestamp` will be converted to a `block-num` by finding the first block \nwhere the block''s `created_at` is less than or equal to the given `timestamp` (i.e. `block''s created_at <= timestamp`). \n\nThe function will interpret and convert the input based on its format, example input:\n\n* `2016-09-15 19:47:21`\n\n* `5000000`\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Given block''s stats\n\n* Returns `hafah_backend.block`\n",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/hafah_backend.block"
                },
                "example": [
                  {
                    "block_num": 5000000,
                    "hash": "004c4b40245ffb07380a393fb2b3d841b76cdaec",
                    "prev": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
                    "producer_account": "ihashfury",
                    "transaction_merkle_root": "97a8f2b04848b860f1792dc07bf58efcb15aeb8c",
                    "extensions": [],
                    "witness_signature": "1f6aa1c6311c768b5225b115eaf5798e5f1d8338af3970d90899cd5ccbe38f6d1f7676c5649bcca18150cbf8f07c0cc7ec3ae40d5936cfc6d5a650e582ba0f8002",
                    "signing_key": "STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2",
                    "hbd_interest_rate": 1000,
                    "total_vesting_fund_hive": 149190428013,
                    "total_vesting_shares": 448144916705468350,
                    "total_reward_fund_hive": 66003975,
                    "virtual_supply": 161253662237,
                    "current_supply": 157464400971,
                    "current_hbd_supply": 2413759427,
                    "dhf_interval_ledger": 0,
                    "created_at": "2016-09-15T19:47:21"
                  }
                ]
              }
            }
          },
          "404": {
            "description": "No blocks in the database"
          }
        }
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
