SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}/operations:
  get:
    tags:
      - Blocks
    summary: Get operations in block
    description: |
      List the operations in the specified order that are within the given block number. 
      The page size determines the number of operations per page

      SQL example
      * `SELECT * FROM hafah_endpoints.get_ops_by_block_paging(5000000,''5,64'');`
      
      REST call example
      * `GET ''https://%1$s/hafah-api/blocks/5000000/operations?operation-types=80&path-filter=value.creator=steem''`
    operationId: hafah_endpoints.get_ops_by_block_paging
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
        name: operation-types
        required: false
        schema:
          type: string
          default: NULL
        description: |
          List of operations: if the parameter is empty, all operations will be included,
          example: `18,12`
      - in: query
        name: account-name
        required: false
        schema:
          type: string
          default: NULL
        description: Filter operations by the account that created them
      - in: query
        name: page
        required: false
        schema:
          type: integer
          default: 1
        description: Return page on `page` number, defaults to `1`
      - in: query
        name: page-size
        required: false
        schema:
          type: integer
          default: 100
        description: Return max `page-size` operations per page, defaults to `100`
      - in: query
        name: page-order
        required: false
        schema:
          $ref: '#/components/schemas/hafah_backend.sort_direction'
          default: desc
        description: |
          page order:

           * `asc` - Ascending, from oldest to newest page
           
           * `desc` - Descending, from newest to oldest page
      - in: query
        name: data-size-limit
        required: false
        schema:
          type: integer
          default: 200000
        description: |
          If the operation length exceeds the data size limit,
          the operation body is replaced with a placeholder, defaults to `200000`
      - in: query
        name: path-filter
        required: false
        schema:
          type: array
          items:
            type: string
          default: NULL
        description: |
          A parameter specifying the expected value in operation body,
          example: `value.creator=steem`
    responses:
      '200':
        description: |
          Result contains total operations number,
          total pages and the list of operations

          * Returns `hafah_backend.operation_history`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.operation_history'
            example: {
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
      '404':
        description: The result is empty
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_ops_by_block_paging;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_ops_by_block_paging(
    "block-num" TEXT,
    "operation-types" TEXT = NULL,
    "account-name" TEXT = NULL,
    "page" INT = 1,
    "page-size" INT = 100,
    "page-order" hafah_backend.sort_direction = 'desc',
    "data-size-limit" INT = 200000,
    "path-filter" TEXT[] = NULL
)
RETURNS hafah_backend.operation_history 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
  __block INT := hive.convert_to_block_num("block-num");
  _operation_types INT[] := (CASE WHEN "operation-types" IS NOT NULL THEN string_to_array("operation-types", ',')::INT[] ELSE NULL END);
  _key_content TEXT[] := NULL;
  _set_of_keys JSON := NULL;
  _result hafah_backend.operation[];
  _account_id INT := NULL;

  _ops_count INT;
  __total_pages INT;
BEGIN
  PERFORM hafah_python.validate_limit("page-size", 10000, 'page-size');
  PERFORM hafah_python.validate_negative_limit("page-size", 'page-size');
  PERFORM hafah_python.validate_negative_page("page");

  IF __block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('block-num');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM hive.blocks_view bv WHERE bv.num = __block) THEN
    PERFORM hafah_backend.rest_raise_missing_block(__block);
  END IF;

  IF "account-name" IS NOT NULL THEN
    _account_id := (SELECT av.id FROM hive.accounts_view av WHERE av.name = "account-name");

    IF _account_id IS NULL THEN
      PERFORM hafah_backend.rest_raise_missing_account("account-name");
    END IF;
  END IF;

  IF "path-filter" IS NOT NULL AND "path-filter" != '{}' THEN
    SELECT 
      pvpf.param_json::JSON,
      pvpf.param_text::TEXT[]
    INTO _set_of_keys, _key_content
    FROM hafah_backend.parse_path_filters("path-filter") pvpf;
  END IF;

  IF __block <= hive.app_get_irreversible_block() AND __block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  _ops_count := (
    SELECT hafah_backend.get_ops_by_block_count(
      __block,
      _operation_types,
      _account_id,
      _key_content,
      _set_of_keys
    )
  );

  __total_pages := (
    CASE 
      WHEN (_ops_count % "page-size") = 0 THEN 
        _ops_count/"page-size" 
      ELSE 
        (_ops_count/"page-size") + 1
    END
  );

  PERFORM hafah_python.validate_page("page", __total_pages);

  _result := array_agg(row ORDER BY
      (CASE WHEN "page-order" = 'desc' THEN row.operation_id::BIGINT ELSE NULL END) DESC,
      (CASE WHEN "page-order" = 'asc' THEN row.operation_id::BIGINT ELSE NULL END) ASC
    ) FROM (
      SELECT 
        ba.op,
        ba.block,
        ba.trx_id,
        ba.op_pos,
        ba.op_type_id,
        ba.timestamp,
        ba.virtual_op,
        ba.operation_id,
        ba.trx_in_block
      FROM hafah_backend.get_ops_by_block(
        __block, 
        "page",
        "page-size",
        _operation_types,
        "page-order",
        "data-size-limit",
        _account_id,
        _key_content,
        _set_of_keys
        ) ba
  ) row;

  RETURN (
    COALESCE(_ops_count,0),
    COALESCE(__total_pages,0),
    COALESCE(_result, '{}'::hafah_backend.operation[])
  )::hafah_backend.operation_history;

END
$$;

RESET ROLE;
