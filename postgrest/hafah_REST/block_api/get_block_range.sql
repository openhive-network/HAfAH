SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}/range:
  get:
    tags:
      - Blocks
    summary: Get block details in range
    description: |
      Retrieve a range of full, signed blocks.
      The list may be shorter than requested if count blocks would take you past the current head block. 

      SQL example
      * `SELECT * FROM hafah_rest.get_block_range(500000);`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/blocks/500000/range`
    operationId: hafah_rest.get_block_range
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
          default: NULL
        description: Height of the first block to be returned
      - in: query
        name: block-count
        required: false
        schema:
          type: integer
          default: 100
        description: the maximum number of blocks to return
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
                  "blocks": []
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_block_range;
CREATE OR REPLACE FUNCTION hafah_rest.get_block_range(
    "block-num" INT = NULL,
    "block-count" INT = 100,
    "id" INT = 1
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __starting_block_num BIGINT = NULL;
    __block_count BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  -- Required argument: block-num
  IF "block-num" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('block-num', "id");
  ELSE
      __starting_block_num = "block-num"::BIGINT;
      IF __starting_block_num < 0 THEN
          __starting_block_num := __starting_block_num + ((POW(2, 31) - 1) :: BIGINT);
      END IF;        
  END IF;

  __block_count = "block-count"::BIGINT;
  IF __block_count < 0 THEN
      __block_count := __block_count + ((POW(2, 31) - 1) :: BIGINT);
  END IF;

  BEGIN
    RETURN hive.get_block_range_json(__starting_block_num::INT, __block_count::INT);

    EXCEPTION
      WHEN invalid_text_representation THEN
        RETURN hafah_backend.rest_raise_uint_exception("id");
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message, "id");
  END;
END
$$
;

RESET ROLE;
