SET ROLE hafah_owner;

/** openapi:paths
/operations/virtual:
  get:
    tags:
      - Operations
    summary: Get virtual operations in block range
    description: |
      Allows to specify range of blocks to retrieve virtual operations.

      SQL example
      * `SELECT * FROM hafah_rest.enum_virtual_ops(200,300);`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/operations/virtual?from-block=200&to-block=300`
    operationId: hafah_rest.enum_virtual_ops
    parameters:
      - in: query
        name: from-block
        required: true
        schema:
          type: integer
          default: NULL
        description: 
      - in: query
        name: to-block
        required: true
        schema:
          type: integer
          default: NULL
        description: 
      - in: query
        name: operation-begin
        required: false
        schema:
          type: integer
          x-sql-datatype: BIGINT
          default: 0
        description: Starting virtual operation in given block (inclusive)
      - in: query
        name: page-size
        required: false
        schema:
          type: integer
          default: 150000
        description: 
          A limit of retrieved operations,
          up to 150000
      - in: query
        name: filter
        required: false
        schema:
          type: integer
          x-sql-datatype: numeric
          default: NULL
        description: | 
          A  filter that decides which an operation matches - used bitwise filtering equals to position such as:

          - fill_convert_request_operation = 0x000001
          - author_reward_operation = 0x000002
          - curation_reward_operation = 0x000004
          - comment_reward_operation = 0x000008
          - liquidity_reward_operation = 0x000010
          - interest_operation = 0x000020
          - fill_vesting_withdraw_operation = 0x000040
          - fill_order_operation = 0x000080
          - shutdown_witness_operation = 0x000100
          - fill_transfer_from_savings_operation = 0x000200
          - hardfork_operation = 0x000400
          - comment_payout_update_operation = 0x000800
          - comment_payout_update_operation = 0x000800
          - return_vesting_delegation_operation = 0x001000
          - comment_benefactor_reward_operation = 0x002000
          - producer_reward_operation = 0x004000
          - clear_null_account_balance_operation = 0x008000
          - proposal_pay_operation = 0x010000
          - sps_fund_operation = 0x020000
          - hardfork_hive_operation = 0x040000
          - hardfork_hive_restore_operation = 0x080000
          - delayed_voting_operation = 0x100000
          - consolidate_treasury_balance_operation = 0x200000
          - effective_comment_vote_operation = 0x400000
          - ineffective_delete_comment_operation = 0x800000
          - sps_convert_operation = 0x1000000
          - dhf_funding_operation = 0x0020000
          - dhf_conversion_operation = 0x1000000
          - expired_account_notification_operation = 0x2000000
          - changed_recovery_account_operation = 0x4000000
          - transfer_to_vesting_completed_operation = 0x8000000
          - pow_reward_operation = 0x10000000
          - vesting_shares_split_operation = 0x20000000
          - account_created_operation = 0x40000000
          - fill_collateralized_convert_request_operation = 0x80000000
          - system_warning_operation = 0x100000000
          - fill_recurrent_transfer_operation = 0x200000000
          - failed_recurrent_transfer_operation = 0x400000000
          - limit_order_cancelled_operation = 0x800000000
          - producer_missed_operation = 0x1000000000
          - proposal_fee_operation = 0x2000000000
          - collateralized_convert_immediate_conversion_operation = 0x4000000000
          - escrow_approved_operation = 0x8000000000
          - escrow_rejected_operation = 0x10000000000
          - proxy_cleared_operation = 0x20000000000
      - in: query
        name: include-reversible
        required: false
        schema:
          type: boolean
          default: false
        description: |
          If set to true also operations from reversible block will be included if block_num points to such block
      - in: query
        name: group-by-block
        required: false
        schema:
          type: boolean
          default: false
        description: true/false
      - in: query
        name: id
        required: false
        schema:
          type: integer
          default: 1
        description: 
    responses:
      '200':
        description: |

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSON
            example: 
              - {
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
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.enum_virtual_ops;
CREATE OR REPLACE FUNCTION hafah_rest.enum_virtual_ops(
    "from-block" INT = NULL,
    "to-block" INT = NULL,
    "operation-begin" BIGINT = 0,
    "page-size" INT = 150000,
    "filter" numeric = NULL,
    "include-reversible" BOOLEAN = False,
    "group-by-block" BOOLEAN = False,
    "id" INT = 1
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __exception_message TEXT;
BEGIN
    -- Required argument: to-block, from-block
  IF "from-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('from-block', "id");
  END IF;

  IF "to-block" IS NULL THEN
    RETURN hafah_backend.rest_raise_missing_arg('to-block', "id");
  END IF;

  BEGIN
    RETURN hafah_python.enum_virtual_ops_json(
      "filter",
      "from-block",
      "to-block",
      "operation-begin",
      "page-size",
      "include-reversible",
      "group-by-block"
    );
    EXCEPTION
    WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS __exception_message = message_text;
      RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END
$$
;

RESET ROLE;
