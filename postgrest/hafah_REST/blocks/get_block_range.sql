SET ROLE hafah_owner;

/** openapi:paths
/blocks:
  get:
    tags:
      - Blocks
    summary: Get block details in range
    description: |
      Retrieve a range of full, signed blocks.
      The list may be shorter than requested if count blocks would take you past the current head block. 

      SQL example
      * `SELECT * FROM hafah_endpoints.get_block_range(1000000,1001000);`

      REST call example
      * `GET https://{hafah-host}/hafah/blocks?from-block=1000000&to-block=1001000`
    operationId: hafah_endpoints.get_block_range
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
      '404':
        description: 
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_block_range;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_block_range(
    "from-block" INT = NULL,
    "to-block" INT = NULL,
    "id" INT = 1
)
RETURNS JSON 
-- openapi-generated-code-end
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __block_num BIGINT = NULL;
    __end_block_num BIGINT = NULL;
    __exception_message TEXT;
BEGIN
  -- Required argument: block-num
  IF "from-block" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('from-block', "id");
  ELSE
    __block_num = "from-block"::BIGINT;
    IF __block_num < 0 THEN
      __block_num := __block_num + ((POW(2, 31) - 1) :: BIGINT);
    END IF;     
  END IF;

  IF "to-block" IS NULL THEN
      RETURN hafah_backend.rest_raise_missing_arg('to-block', "id");
  ELSE
    __end_block_num = "to-block"::BIGINT;
    IF __end_block_num < 0 THEN
      __end_block_num := __end_block_num + ((POW(2, 31) - 1) :: BIGINT);
    ELSE

    END IF;

  END IF;

  BEGIN
    RETURN hafah_python.get_block_range_json(__block_num::INT, __end_block_num::INT);

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
