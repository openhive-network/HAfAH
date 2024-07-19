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

create or replace function hafah_endpoints.home() returns json as $_$
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
        "description": "Retrieve a range of full, signed blocks.\nThe list may be shorter than requested if count blocks would take you past the current head block. \n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_range(1000000,1001000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks?from-block=1000000&to-block=1001000`\n",
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
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                    "blocks": [
                      {
                        "witness": "initminer",
                        "block_id": "000003e8b922f4906a45af8e99d86b3511acd7a5",
                        "previous": "000003e7c4fd3221cf407efcf7c1730e2ca54b05",
                        "timestamp": "2016-03-24T16:55:30",
                        "extensions": [],
                        "signing_key": "STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX",
                        "transactions": [],
                        "transaction_ids": [],
                        "witness_signature": "207f15578cac20ac0e8af1ebb8f463106b8849577e21cca9fc60da146d1d95df88072dedc6ffb7f7f44a9185bbf9bf8139a5b4285c9f423843720296a44d428856",
                        "transaction_merkle_root": "0000000000000000000000000000000000000000"
                      },
                      {
                        "witness": "initminer",
                        "block_id": "000003e952b9bf36a17912d6c87255366c81c5ec",
                        "previous": "000003e8b922f4906a45af8e99d86b3511acd7a5",
                        "timestamp": "2016-03-24T16:55:33",
                        "extensions": [],
                        "signing_key": "STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX",
                        "transactions": [],
                        "transaction_ids": [],
                        "witness_signature": "1f37f4113d68be502b9ea8018203273054f4de971b719aaf7945b5a528a827a7fc4a636573469026891119a5a489b2d5c0e291c6a7be880f1a9c374e085b9ca738",
                        "transaction_merkle_root": "0000000000000000000000000000000000000000"
                      }
                    ]
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
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
        "description": "Retrieve a full, signed block of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block(500000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/500000`\n",
        "operationId": "hafah_endpoints.get_block",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                    "block": {
                      "witness": "initminer",
                      "block_id": "000003e8b922f4906a45af8e99d86b3511acd7a5",
                      "previous": "000003e7c4fd3221cf407efcf7c1730e2ca54b05",
                      "timestamp": "2016-03-24T16:55:30",
                      "extensions": [],
                      "signing_key": "STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX",
                      "transactions": [],
                      "transaction_ids": [],
                      "witness_signature": "207f15578cac20ac0e8af1ebb8f463106b8849577e21cca9fc60da146d1d95df88072dedc6ffb7f7f44a9185bbf9bf8139a5b4285c9f423843720296a44d428856",
                      "transaction_merkle_root": "0000000000000000000000000000000000000000"
                    }
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
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
        "description": "Retrieve a block header of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_block_header(500000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/500000/header`\n",
        "operationId": "hafah_endpoints.get_block_header",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Height of the block whose header should be returned\n"
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                    "header": {
                      "witness": "initminer",
                      "previous": "000003e7c4fd3221cf407efcf7c1730e2ca54b05",
                      "timestamp": "2016-03-24T16:55:30",
                      "extensions": [],
                      "transaction_merkle_root": "0000000000000000000000000000000000000000"
                    }
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
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
        "description": "Returns all operations contained in a block.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_ops_in_block(213124);`\n\n* `SELECT * FROM hafah_endpoints.get_ops_in_block(5000000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/213124/operations`\n\n* `GET https://{hafah-host}/hafah-rest/blocks/5000000/operations`\n",
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
            "description": null
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
            "name": "only-virtual",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
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
            "name": "is-legacy-style",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                        "block": 1000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-03-24T16:55:30",
                        "virtual_op": true,
                        "operation_id": 4294967296064,
                        "trx_in_block": 4294967295
                      }
                    ],
                    "next_operation_begin": 0
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
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
        "description": "Returns all operations contained in provided block range\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_operations(200,300);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/operations?from-block=200&to-block=300`\n",
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
            "name": "only-virtual",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
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
            "name": "is-legacy-style",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                        "block": 1000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-03-24T16:55:30",
                        "virtual_op": true,
                        "operation_id": 4294967296064,
                        "trx_in_block": 4294967295
                      }
                    ],
                    "next_operation_begin": 0,
                    "next_block_range_begin": 1001
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
          }
        }
      }
    },
    "/operations/virtual": {
      "get": {
        "tags": [
          "Operations"
        ],
        "summary": "Get virtual operations in block range",
        "description": "Allows to specify range of blocks to retrieve virtual operations.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.enum_virtual_ops(200,300);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/operations/virtual?from-block=200&to-block=300`\n",
        "operationId": "hafah_endpoints.enum_virtual_ops",
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
            "description": null
          },
          {
            "in": "query",
            "name": "operation-begin",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "BIGINT",
              "default": 0
            },
            "description": "Starting virtual operation in given block (inclusive)"
          },
          {
            "in": "query",
            "name": "page-size",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 150000
            },
            "description": "A limit of retrieved operations, up to 150000"
          },
          {
            "in": "query",
            "name": "filter",
            "required": false,
            "schema": {
              "type": "integer",
              "x-sql-datatype": "numeric",
              "default": null
            },
            "description": "A  filter that decides which an operation matches - used bitwise filtering equals to position such as:\n\n- fill_convert_request_operation = 0x000001\n- author_reward_operation = 0x000002\n- curation_reward_operation = 0x000004\n- comment_reward_operation = 0x000008\n- liquidity_reward_operation = 0x000010\n- interest_operation = 0x000020\n- fill_vesting_withdraw_operation = 0x000040\n- fill_order_operation = 0x000080\n- shutdown_witness_operation = 0x000100\n- fill_transfer_from_savings_operation = 0x000200\n- hardfork_operation = 0x000400\n- comment_payout_update_operation = 0x000800\n- comment_payout_update_operation = 0x000800\n- return_vesting_delegation_operation = 0x001000\n- comment_benefactor_reward_operation = 0x002000\n- producer_reward_operation = 0x004000\n- clear_null_account_balance_operation = 0x008000\n- proposal_pay_operation = 0x010000\n- sps_fund_operation = 0x020000\n- hardfork_hive_operation = 0x040000\n- hardfork_hive_restore_operation = 0x080000\n- delayed_voting_operation = 0x100000\n- consolidate_treasury_balance_operation = 0x200000\n- effective_comment_vote_operation = 0x400000\n- ineffective_delete_comment_operation = 0x800000\n- sps_convert_operation = 0x1000000\n- dhf_funding_operation = 0x0020000\n- dhf_conversion_operation = 0x1000000\n- expired_account_notification_operation = 0x2000000\n- changed_recovery_account_operation = 0x4000000\n- transfer_to_vesting_completed_operation = 0x8000000\n- pow_reward_operation = 0x10000000\n- vesting_shares_split_operation = 0x20000000\n- account_created_operation = 0x40000000\n- fill_collateralized_convert_request_operation = 0x80000000\n- system_warning_operation = 0x100000000\n- fill_recurrent_transfer_operation = 0x200000000\n- failed_recurrent_transfer_operation = 0x400000000\n- limit_order_cancelled_operation = 0x800000000\n- producer_missed_operation = 0x1000000000\n- proposal_fee_operation = 0x2000000000\n- collateralized_convert_immediate_conversion_operation = 0x4000000000\n- escrow_approved_operation = 0x8000000000\n- escrow_rejected_operation = 0x10000000000\n- proxy_cleared_operation = 0x20000000000\n"
          },
          {
            "in": "query",
            "name": "include-reversible",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "If set to true also operations from reversible block will be included if block_num points to such block\n"
          },
          {
            "in": "query",
            "name": "group-by-block",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": "true/false"
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                        "block": 1000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-03-24T16:55:30",
                        "virtual_op": true,
                        "operation_id": 4294967296064,
                        "trx_in_block": 4294967295
                      }
                    ],
                    "ops_by_block": [],
                    "next_operation_begin": 0,
                    "next_block_range_begin": 1001
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
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
        "description": "Returns the details of a transaction based on a transaction id (including their signatures,\noperations like also a block_num it was included to).\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_transaction('954f6de36e6715d128fa8eb5a053fc254b05ded0');`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0`\n",
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
          },
          {
            "in": "query",
            "name": "is-legacy-style",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
          },
          "404": {
            "description": null
          }
        }
      }
    },
    "/accounts/{account-name}/operations": {
      "get": {
        "tags": [
          "Accounts"
        ],
        "summary": "Get account's history",
        "description": "Returns a history of all operations for a given account.\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_account_history('blocktrades');`\n\n* `SELECT * FROM hafah_endpoints.get_account_history('gtg');`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/accounts/blocktrades/operations`\n\n* `GET https://{hafah-host}/hafah-rest/accounts/gtg/operations`\n",
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
            "description": null
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
              "default": null
            },
            "description": null
          },
          {
            "in": "query",
            "name": "operation-filter-high",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": null
          },
          {
            "in": "query",
            "name": "is-legacy-style",
            "required": false,
            "schema": {
              "type": "boolean",
              "default": false
            },
            "description": null
          },
          {
            "in": "query",
            "name": "id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 1
            },
            "description": null
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
                    "history": [
                      [
                        4416,
                        {
                          "op": {
                            "type": "effective_comment_vote_operation",
                            "value": {
                              "voter": "gtg",
                              "author": "skypilot",
                              "weight": "19804864940707296",
                              "rshares": 87895502383,
                              "permlink": "sunset-at-point-sur-california",
                              "pending_payout": {
                                "nai": "@@000000013",
                                "amount": "14120",
                                "precision": 3
                              },
                              "total_vote_weight": "14379148533547713492"
                            }
                          },
                          "block": 4999982,
                          "trx_id": "fa7c8ac738b4c1fdafd4e20ee6ca6e431b641de3",
                          "op_in_trx": 1,
                          "timestamp": "2016-09-15T19:46:24",
                          "virtual_op": true,
                          "operation_id": 0,
                          "trx_in_block": 0
                        }
                      ]
                    ]
                  }
                ]
              }
            }
          },
          "404": {
            "description": null
          }
        }
      }
    },
    "/version": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "hafah's version",
        "description": "Get hafah's last commit hash that determinates its version\n\nSQL example\n* `SELECT * FROM hafah_endpoints.get_version();`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/version`\n",
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
  }
}
$$;
-- openapi-generated-code-end
begin
  return openapi;
end
$_$ language plpgsql;

RESET ROLE;
