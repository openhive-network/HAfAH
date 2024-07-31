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
      * `SELECT * FROM hafah_endpoints.get_block_header(500000);`

      REST call example
      * `GET ''https://%1$s/hafah/blocks/500000/header''`
    operationId: hafah_endpoints.get_block_header
    parameters:
      - in: path
        name: block-num
        required: true
        schema:
          type: integer
        description: Given block number
    responses:
      '200':
        description: |

          * Returns `JSONB`
        content:
          application/json:
            schema:
              type: string
              x-sql-datatype: JSONB
            example: 
              - {
                  "witness": "ihashfury",
                  "previous": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
                  "timestamp": "2016-09-15T19:47:21",
                  "extensions": [],
                  "transaction_merkle_root": "97a8f2b04848b860f1792dc07bf58efcb15aeb8c"
                }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_block_header;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_block_header(
    "block-num" INT
)
RETURNS JSONB 
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
      RETURN hafah_backend.rest_raise_missing_arg('block-num');
  ELSE
      __block_num = "block-num"::BIGINT;
      IF __block_num < 0 THEN
          __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
      END IF;        
  END IF;

  BEGIN
    RETURN hafah_python.get_block_header_json(__block_num::INT);

    EXCEPTION
      WHEN invalid_text_representation THEN
        RETURN hafah_backend.rest_raise_uint_exception();
      WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __exception_message = message_text;
        RETURN hafah_backend.rest_wrap_sql_exception(__exception_message);
  END;
END
$$
;

RESET ROLE;
