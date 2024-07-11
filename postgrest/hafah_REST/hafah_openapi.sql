SET ROLE hafah_owner;

CREATE SCHEMA IF NOT EXISTS hafah_rest AUTHORIZATION hafah_owner;
GRANT USAGE ON SCHEMA hafah_rest TO hafah_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hafah_rest TO hafah_user;

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
  - name: Accounts
    description: Informations about accounts
  - name: Other
    description: General API informations
servers:
  - url: /hafah-rest
 */

create or replace function hafah_rest.root() returns json as $_$
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
      "url": "/hafah-rest"
    }
  ],
  "paths": {
    "/blocks/{block-num}": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block details",
        "description": "Retrieve a full, signed block of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_rest.get_block(500000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/500000`\n",
        "operationId": "hafah_rest.get_block",
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
                      "previous": "0000000000000000000000000000000000000000",
                      "timestamp": "2016-03-24T16:05:00",
                      "witness": "",
                      "transaction_merkle_root": "0000000000000000000000000000000000000000",
                      "extensions": [],
                      "witness_signature": "",
                      "transactions": [],
                      "block_id": "",
                      "signing_key": "",
                      "transaction_ids": []
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
    "/blocks/{block-num}/range": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get block details in range",
        "description": "Retrieve a range of full, signed blocks.\nThe list may be shorter than requested if count blocks would take you past the current head block. \n\nSQL example\n* `SELECT * FROM hafah_rest.get_block_range(500000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/500000/range`\n",
        "operationId": "hafah_rest.get_block_range",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Height of the first block to be returned"
          },
          {
            "in": "query",
            "name": "block-count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 100
            },
            "description": "the maximum number of blocks to return"
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
                    "blocks": []
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
        "description": "Retrieve a block header of the referenced block, or null if no matching block was found.\n\nSQL example\n* `SELECT * FROM hafah_rest.get_block_header(500000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/500000/header`\n",
        "operationId": "hafah_rest.get_block_header",
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
                      "previous": "0000000000000000000000000000000000000000",
                      "timestamp": "2016-03-24T16:05:00",
                      "witness": "",
                      "transaction_merkle_root": "0000000000000000000000000000000000000000",
                      "extensions": []
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
        "summary": "Get operations in blocks",
        "description": "Returns all operations contained in a block.\n\nSQL example\n* `SELECT * FROM hafah_rest.get_ops_in_block(213124);`\n\n* `SELECT * FROM hafah_rest.get_ops_in_block(5000000);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/213124/operations`\n\n* `GET https://{hafah-host}/hafah-rest/blocks/5000000/operations`\n",
        "operationId": "hafah_rest.get_ops_in_block",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": 0
            },
            "description": null
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
                        "trx_id": "0000000000000000000000000000000000000000",
                        "block": 0,
                        "trx_in_block": 4294967295,
                        "op_in_trx": 0,
                        "virtual_op": 0,
                        "timestamp": "2019-10-06T09:05:15",
                        "op": {}
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
    "/blocks/{block-num}/operations/virtual": {
      "get": {
        "tags": [
          "Blocks"
        ],
        "summary": "Get virtual operations in block range",
        "description": "Allows to specify range of blocks to retrieve virtual operations for.\n\nSQL example\n* `SELECT * FROM hafah_rest.enum_virtual_ops(100000,200);`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/blocks/100000/virtual-ops?block-count=200`\n",
        "operationId": "hafah_rest.enum_virtual_ops",
        "parameters": [
          {
            "in": "path",
            "name": "block-num",
            "required": true,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Starting block number (inclusive) to search for virtual operations\n"
          },
          {
            "in": "query",
            "name": "block-count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 100
            },
            "description": "The maximum number of blocks to return\n"
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
            "name": "limit",
            "required": false,
            "schema": {
              "type": "integer",
              "default": 150000
            },
            "description": "A limit of retrieved operations"
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
                            "producer": "sminer22",
                            "vesting_shares": {
                              "nai": "@@000000021",
                              "amount": "1000",
                              "precision": 3
                            }
                          }
                        },
                        "block": 46000,
                        "trx_id": "0000000000000000000000000000000000000000",
                        "op_in_trx": 1,
                        "timestamp": "2016-03-26T06:58:12",
                        "virtual_op": true,
                        "operation_id": 197568495616064,
                        "trx_in_block": 4294967295
                      }
                    ],
                    "ops_by_block": [],
                    "next_operation_begin": 0,
                    "next_block_range_begin": 46001
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
        "description": "Returns the details of a transaction based on a transaction id (including their signatures,\noperations like also a block_num it was included to).\n\nSQL example\n* `SELECT * FROM hafah_rest.get_transaction('954f6de36e6715d128fa8eb5a053fc254b05ded0');`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/transactions/954f6de36e6715d128fa8eb5a053fc254b05ded0`\n",
        "operationId": "hafah_rest.get_transaction",
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
                    "ref_block_num": 36374,
                    "ref_block_prefix": 3218139339,
                    "expiration": "2018-04-09T00:29:06",
                    "operations": [
                      {
                        "type": "claim_reward_balance_operation",
                        "value": {
                          "account": "social",
                          "reward_hive": {
                            "amount": "0",
                            "precision": 3,
                            "nai": "@@000000021"
                          },
                          "reward_hbd": {
                            "amount": "0",
                            "precision": 3,
                            "nai": "@@000000013"
                          },
                          "reward_vests": {
                            "amount": "1",
                            "precision": 6,
                            "nai": "@@000000037"
                          }
                        }
                      }
                    ],
                    "extensions": [],
                    "signatures": [
                      "1b01bdbb0c0d43db821c09ae8a82881c1ce3ba0eca35f23bc06541eca05560742f210a21243e20d04d5c88cb977abf2d75cc088db0fff2ca9fdf2cba753cf69844"
                    ],
                    "transaction_id": "6fde0190a97835ea6d9e651293e90c89911f933c",
                    "block_num": 21401130,
                    "transaction_num": 25
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
        "description": "Returns a history of all operations for a given account.\n\nSQL example\n* `SELECT * FROM hafah_rest.get_account_history('blocktrades');`\n\n* `SELECT * FROM hafah_rest.get_account_history('gtg');`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/accounts/blocktrades/operations`\n\n* `GET https://{hafah-host}/hafah-rest/accounts/gtg/operations`\n",
        "operationId": "hafah_rest.get_account_history",
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
            "name": "limit",
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
                        99,
                        {
                          "trx_id": "0000000000000000000000000000000000000000",
                          "block": 0,
                          "trx_in_block": 4294967295,
                          "op_in_trx": 0,
                          "virtual_op": 0,
                          "timestamp": "2019-12-09T21:32:39",
                          "op": {}
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
    "/hafah-version": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "hafah's version",
        "description": "Get hafah's last commit hash that determinates its version\n\nSQL example\n* `SELECT * FROM hafah_rest.get_version();`\n\nREST call example\n* `GET https://{hafah-host}/hafah-rest/hafah-version`\n",
        "operationId": "hafah_rest.get_version",
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
