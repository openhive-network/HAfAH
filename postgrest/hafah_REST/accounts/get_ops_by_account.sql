SET ROLE hafah_owner;

/** openapi:paths
/accounts/{account-name}/operations:
  get:
    tags:
      - Accounts
    summary: Get operations for an account by recency.
    description: |
      List the operations in reversed order (first page is the oldest) for given account. 
      The page size determines the number of operations per page.

      SQL example
      * `SELECT * FROM hafah_endpoints.get_ops_by_account(''blocktrades'');`

      REST call example
      * `GET ''https://%1$s/hafah-api/accounts/blocktrades/operations?page-size=3''`
    operationId: hafah_endpoints.get_ops_by_account
    parameters:
      - in: path
        name: account-name
        required: true
        schema:
          type: string
        description: Account to get operations for.
      - in: query
        name: operation-types
        required: false
        schema:
          type: string
          default: NULL
        description: |
          List of operation types to get. If NULL, gets all operation types.
          example: `18,12`
      - in: query
        name: page
        required: false
        schema:
          type: integer
          default: NULL
        description: |
          Return page on `page` number, default null due to reversed order of pages,
          the first page is the oldest,
          example: first call returns the newest page and total_pages is 100 - the newest page is number 100, next 99 etc.
      - in: query
        name: page-size
        required: false
        schema:
          type: integer
          default: 100
        description: Return max `page-size` operations per page, defaults to `100`.
      - in: query
        name: data-size-limit
        required: false
        schema:
          type: integer
          default: 200000
        description: |
          If the operation length exceeds the data size limit,
          the operation body is replaced with a placeholder (defaults to `200000`).
      - in: query
        name: from-block
        required: false
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
        required: false
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
          Result contains total number of operations,
          total pages, and the list of operations.

          * Returns `JSON`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSON
            example: 
              - {
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
      '404':
        description: No such account in the database
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_ops_by_account;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_ops_by_account(
    "account-name" TEXT,
    "operation-types" TEXT = NULL,
    "page" INT = NULL,
    "page-size" INT = 100,
    "data-size-limit" INT = 200000,
    "from-block" TEXT = NULL,
    "to-block" TEXT = NULL
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET join_collapse_limit = 16
SET from_collapse_limit = 16
SET JIT = OFF
SET enable_hashjoin = OFF
SET plan_cache_mode = force_custom_plan
-- force_custom_plan added to every function that uses OFFSET
AS
$$
DECLARE 
  _block_range hive.blocks_range := hive.convert_to_blocks_range("from-block","to-block");
  _ops_count BIGINT;
  _calculate_total_pages INT; 
  _operation_types INT[] := (SELECT string_to_array("operation-types", ',')::INT[]);
BEGIN
SELECT hafah_backend.get_account_operations_count(_operation_types, "account-name", _block_range.first_block, _block_range.last_block) INTO _ops_count;

SELECT (CASE WHEN (_ops_count % "page-size") = 0 THEN 
    _ops_count/"page-size" ELSE ((_ops_count/"page-size") + 1) END)::INT INTO _calculate_total_pages;

IF (_block_range.last_block <= hive.app_get_irreversible_block() AND _block_range.last_block IS NOT NULL) OR ("page" IS NOT NULL AND _calculate_total_pages != "page") THEN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
ELSE
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
END IF;

RETURN (
  SELECT json_build_object(
-- ops_count returns number of operations found with current filter
    'total_operations', _ops_count,
-- to count total_pages we need to check if there was a rest from division by "page-size", if there was the page count is +1 
    'total_pages', _calculate_total_pages,
    'operations_result', 
    (SELECT to_json(array_agg(row)) FROM (
      SELECT * FROM hafah_backend.get_ops_by_account("account-name", 
-- there is two diffrent page_nums, internal and external, internal page_num is ascending (first page with the newest operation is number 1)
-- external page_num is descending, its given by FE and recalculated by this query to internal 

-- to show the first page on account_page on FE we take page_num as NULL, because FE on the first use of the endpoint doesn't know the ops_count
-- For example query returns 15 pages and FE asks for:
-- page 15 (external first page) 15 - 15 + 1 = 1 (internal first page)
-- page 14 (external second page) 15 - 14 + 1 = 2 (internal second page)
-- ... page 7, 15 - 7 + 1 =  9 (internal 9th page)
      (CASE WHEN "page" IS NULL THEN 1 ELSE ((_calculate_total_pages - "page") + 1) END)::INT,
      "page-size",
      _operation_types,
      _block_range.first_block,
      _block_range.last_block,
      "data-size-limit",
      (_ops_count % "page-size")::INT,
      _ops_count::INT)

-- to return the first page with the rest of the division of ops count the number is handed over to backend function
    ) row)
  ));

END
$$;

RESET ROLE;
