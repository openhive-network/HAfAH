SET ROLE hafah_owner;

create or replace function hafah_endpoints.home() returns json as $_$
declare
-- openapi-spec
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
      "name": "account_history_api",
      "description": ""
    },
    {
      "name": "block_api",
      "description": ""
    }
  ],
  "servers": [
    {
      "url": "/hafah"
    }
  ],
  "paths": {
    "/#1": {
      "post": {
        "tags": [
          "account_history_api"
        ],
        "summary": "get_account_history",
        "description": "Returns a history of all operations for a given account. Parameters:\n\n- account:string\n- start:int. e.g.: -1 for reverse history or any positive numeric\n- limit:int up to 1000\n- include_reversible:boolean (optional) If set to true also operations from reversible block will be included\n- operation_filter_low:int (optional)\n- operation_filter_high:int (optional)",
        "operationId": "reptracker_endpoints.home.get_account_history",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/account_history"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "History of all operations for a given account",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
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
          }
        }
      }
    },
    "/#2": {
      "post": {
        "tags": [
          "account_history_api"
        ],
        "summary": "get_transaction",
        "description": "Returns the details of a transaction based on a transaction id (including their signatures, operations like also a block_num it was included to).\n\n- id:string trx_id of expected transaction\n- include_reversible:boolean (optional) If set to true also operations from reversible block will be included if block_num points to such block.",
        "operationId": "reptracker_endpoints.home.get_transaction",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/transaction"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "Details of a transaction",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
                },
                "example": [
                  {
                    "jsonrpc": "2.0",
                    "result": {
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
                    },
                    "id": 1
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/#3": {
      "post": {
        "tags": [
          "account_history_api"
        ],
        "summary": "enum_virtual_ops",
        "description": "Allows to specify range of blocks to retrieve virtual operations for.\n\n- block_range_begin:int starting block number (inclusive) to search for virtual operations\n- block_range_end:int last block number (exclusive) to search for virtual operations\n- block_range_end:int last block number (exclusive) to search for virtual operations\n- include_reversible:boolean (optional) If set to true also operations from reversible block will be included if block_num points to such block.\n- group_by_block (optional) true/false\n- operation_begin (optional) starting virtual operation in given block (inclusive)\n- limit (optional) a limit of retrieved operations\n- filter (optional) a filter that decides which an operation matches - used bitwise filtering equals to position such as:\n- - fill_convert_request_operation = 0x000001\n- - author_reward_operation = 0x000002\n- - curation_reward_operation = 0x000004\n- - comment_reward_operation = 0x000008\n- - liquidity_reward_operation = 0x000010\n- - interest_operation = 0x000020\n- - fill_vesting_withdraw_operation = 0x000040\n- - fill_order_operation = 0x000080\n- - shutdown_witness_operation = 0x000100\n- - fill_transfer_from_savings_operation = 0x000200\n- - hardfork_operation = 0x000400\n- - comment_payout_update_operation = 0x000800\n- - comment_payout_update_operation = 0x000800\n- - return_vesting_delegation_operation = 0x001000\n- - comment_benefactor_reward_operation = 0x002000\n- - producer_reward_operation = 0x004000\n- - clear_null_account_balance_operation = 0x008000\n- - proposal_pay_operation = 0x010000\n- - sps_fund_operation = 0x020000\n- - hardfork_hive_operation = 0x040000\n- - hardfork_hive_restore_operation = 0x080000\n- - delayed_voting_operation = 0x100000\n- - consolidate_treasury_balance_operation = 0x200000\n- - effective_comment_vote_operation = 0x400000\n- - ineffective_delete_comment_operation = 0x800000\n- - sps_convert_operation = 0x1000000\n- - dhf_funding_operation = 0x0020000\n- - dhf_conversion_operation = 0x1000000\n- - expired_account_notification_operation = 0x2000000\n- - changed_recovery_account_operation = 0x4000000\n- - transfer_to_vesting_completed_operation = 0x8000000\n- - pow_reward_operation = 0x10000000\n- - vesting_shares_split_operation = 0x20000000\n- - account_created_operation = 0x40000000\n- - fill_collateralized_convert_request_operation = 0x80000000\n- - system_warning_operation = 0x100000000\n- - fill_recurrent_transfer_operation = 0x200000000\n- - failed_recurrent_transfer_operation = 0x400000000\n- - limit_order_cancelled_operation = 0x800000000\n- - producer_missed_operation = 0x1000000000\n- - proposal_fee_operation = 0x2000000000\n- - collateralized_convert_immediate_conversion_operation = 0x4000000000\n- - escrow_approved_operation = 0x8000000000\n- - escrow_rejected_operation = 0x10000000000\n- - proxy_cleared_operation = 0x20000000000\n",
        "operationId": "reptracker_endpoints.home.enum_virtual_ops",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/virtual_ops"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "Virtual operations",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
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
                        "timestamp": "2016-03-24T17:46:30",
                        "op": {},
                        "operation_id": "18446744069414584320"
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/#4": {
      "post": {
        "tags": [
          "account_history_api"
        ],
        "summary": "get_ops_in_block",
        "description": "Returns all operations contained in a block. Parameter:\n\n- block_num:int\n- only_virtual:boolean\n- include_reversible:boolean (optional) If set to true also operations from reversible block will be included if block_num points to such block.",
        "operationId": "reptracker_endpoints.home.get_ops_in_block",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ops_in_block"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "Operations in block",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
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
          }
        }
      }
    },
    "/#5": {
      "post": {
        "tags": [
          "block_api"
        ],
        "summary": "get_block",
        "description": "Retrieve a full, signed block of the referenced block, or null if no matching block was found, Parameters:\n\n- block_num:int",
        "operationId": "reptracker_endpoints.home.get_block",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/block"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "Block parameters",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
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
          }
        }
      }
    },
    "/#6": {
      "post": {
        "tags": [
          "block_api"
        ],
        "summary": "get_block_header",
        "description": "Retrieve a block header of the referenced block, or null if no matching block was found, Parameters:\n\n- block_num:int - Height of the block whose header should be returned",
        "operationId": "reptracker_endpoints.home.get_block_header",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/block_header"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "Block header",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
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
          }
        }
      }
    },
    "/#7": {
      "post": {
        "tags": [
          "block_api"
        ],
        "summary": "get_block_range",
        "description": "Retrieve a range of full, signed blocks. The list may be shorter than requested if count blocks would take you past the current head block, Parameters:\n\n- starting_block_num - Height of the first block to be returned\n- count - the maximum number of blocks to return",
        "operationId": "reptracker_endpoints.home.get_block_range",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/block_range"
              }
            }
          },
          "required": true
        },
        "responses": {
          "200": {
            "description": "List of blocks",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
                },
                "example": [
                  {
                    "blocks": []
                  }
                ]
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "account_history": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "account_history_api.get_account_history"
          },
          "params": {
            "type": "object",
            "properties": {
              "account": {
                "type": "string",
                "example": "emma"
              },
              "start": {
                "type": "integer",
                "example": -1
              },
              "limit": {
                "type": "integer",
                "example": 1000
              },
              "include_reversible": {
                "type": "boolean",
                "example": true
              },
              "operation_filter_low": {
                "type": "integer",
                "example": 0
              },
              "operation_filter_high": {
                "type": "integer",
                "example": 1
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "transaction": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "account_history_api.get_transaction"
          },
          "params": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string",
                "example": "6fde0190a97835ea6d9e651293e90c89911f933c"
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "virtual_ops": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "account_history_api.enum_virtual_ops"
          },
          "params": {
            "type": "object",
            "properties": {
              "block_range_begin": {
                "type": "integer",
                "example": 1
              },
              "block_range_end": {
                "type": "integer",
                "example": 2
              },
              "include_reversible": {
                "type": "boolean",
                "example": true
              },
              "group_by_block": { 
                "type": "boolean",
                "example": false
              },
              "operation_begin": {
                "type": "integer",
                "example": 0
              },
              "limit": {
                "type": "integer",
                "example": 1000
              },
              "filter": {
                "type": "integer",
                "example": 1
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "ops_in_block": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "account_history_api.get_ops_in_block"
          },
          "params": {
            "type": "object",
            "properties": {
              "block_num": {
                "type": "integer",
                "example": 0
              },
              "only_virtual": {
                "type": "boolean",
                "example": false
              },
              "include_reversible": {
                "type": "boolean",
                "example": true
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "block": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "block_api.get_block"
          },
          "params": {
            "type": "object",
            "properties": {
              "block_num": {
                "type": "integer",
                "example": 0
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "block_header": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "block_api.get_block_header"
          },
          "params": {
            "type": "object",
            "properties": {
              "block_num": {
                "type": "integer",
                "example": 1
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      },
      "block_range": {
        "type": "object",
        "properties": {
          "jsonrpc": {
            "type": "string",
            "example": "2.0"
          },
          "method": {
            "type": "string",
            "example": "block_api.get_block_range"
          },
          "params": {
            "type": "object",
            "properties": {
              "starting_block_num": {
                "type": "integer",
                "example": 0
              },
              "count": {
                "type": "integer",
                "example": 0
              }
            }
          },
          "id": {
            "type": "integer",
            "example": 1
          }
        },
        "required": [
          "jsonrpc",
          "method",
          "id"
        ]
      }
    }
  }
}
$$;
begin
  return openapi;
end
$_$ language plpgsql;

RESET ROLE;
