SET ROLE hafah_owner;

/** openapi:paths
/blocks/{block-num}/header:
  get:
    tags:
      - Blocks
    summary: Get block header of the referenced block
    description: |
      Retrieve a block header of the referenced block, or null if no matching block was found.
      
      SQL example
      * `SELECT * FROM hafah_rest.get_block_header(500000);`

      REST call example
      * `GET https://{hafah-host}/hafah-rest/blocks/500000/header`
    operationId: hafah_rest.get_block_header
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
          default: NULL
        description: |
          Height of the block whose header should be returned
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
                  "header": {
                    "previous": "0000000000000000000000000000000000000000",
                    "timestamp": "2016-03-24T16:05:00",
                    "witness": "",
                    "transaction_merkle_root": "0000000000000000000000000000000000000000",
                    "extensions": []
                  }
                }
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_rest.get_block_header;
CREATE OR REPLACE FUNCTION hafah_rest.get_block_header(
    "block-num" INT = NULL,
    "id" INT = 1
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
    -- Required argument: block-num
  IF "block-num" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('block-num', "id");
  ELSE
      __block_num = "block-num"::BIGINT;
      IF __block_num < 0 THEN
          __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
      END IF;        
  END IF;

  BEGIN
    RETURN hive.get_block_header_json(__block_num::INT);

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
