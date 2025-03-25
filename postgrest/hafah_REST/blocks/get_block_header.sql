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
      * `GET ''https://%1$s/hafah-api/blocks/500000/header''`
    operationId: hafah_endpoints.get_block_header
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
    responses:
      '200':
        description: |

          * Returns `hafah_backend.block_header`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.block_header'
            example: {
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
    "block-num" TEXT
)
RETURNS hafah_backend.block_header 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
    __block INT := hive.convert_to_block_num("block-num");
    __block_num BIGINT = NULL;
BEGIN
    -- Required argument: block-num
  IF __block IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg('block-num');
  ELSE
      __block_num = __block::BIGINT;
      IF __block_num < 0 THEN
          __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
      END IF;        
  END IF;

  IF __block <= hive.app_get_irreversible_block() AND __block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  BEGIN
    RETURN hafah_backend.get_block_header(__block_num::INT);

    EXCEPTION
      WHEN invalid_text_representation THEN
        PERFORM hafah_backend.rest_raise_uint_exception();
  END;
END
$$
;

RESET ROLE;
