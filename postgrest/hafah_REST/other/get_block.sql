SET ROLE hafah_owner;

/** openapi:paths
/global-state:
  get:
    tags:
      - Other
    summary: Reports global state information at the given block.
    description: |
      Reports dgpo-style data for a given block.

      SQL example
      * `SELECT * FROM hafah_endpoints.get_global_state(5000000);`
      
      REST call example      
      * `GET ''https://%1$s/hafah-api/global-state?block-num=5000000''`
    operationId: hafah_endpoints.get_global_state
    parameters:
      - in: query
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
          Given block''s stats

          * Returns `hafah_backend.block`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/hafah_backend.block'
            example: {
              "block_num": 5000000,
              "hash": "004c4b40245ffb07380a393fb2b3d841b76cdaec",
              "prev": "004c4b3fc6a8735b4ab5433d59f4526e4a042644",
              "producer_account": "ihashfury",
              "transaction_merkle_root": "97a8f2b04848b860f1792dc07bf58efcb15aeb8c",
              "extensions": [],
              "witness_signature": "1f6aa1c6311c768b5225b115eaf5798e5f1d8338af3970d90899cd5ccbe38f6d1f7676c5649bcca18150cbf8f07c0cc7ec3ae40d5936cfc6d5a650e582ba0f8002",
              "signing_key": "STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2",
              "hbd_interest_rate": 1000,
              "total_vesting_fund_hive": 149190428013,
              "total_vesting_shares": 448144916705468350,
              "total_reward_fund_hive": 66003975,
              "virtual_supply": 161253662237,
              "current_supply": 157464400971,
              "current_hbd_supply": 2413759427,
              "dhf_interval_ledger": 0,
              "created_at": "2016-09-15T19:47:21"
            }
      '404':
        description: No blocks in the database
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS hafah_endpoints.get_global_state;
CREATE OR REPLACE FUNCTION hafah_endpoints.get_global_state(
    "block-num" TEXT
)
RETURNS hafah_backend.block 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
SET JIT = OFF
SET join_collapse_limit = 16
SET from_collapse_limit = 16
AS
$$
DECLARE
    __block INT := hive.convert_to_block_num("block-num");
BEGIN

  IF __block <= hive.app_get_irreversible_block() AND __block IS NOT NULL THEN
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=31536000"}]', true);
  ELSE
    PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);
  END IF;

  RETURN (
  SELECT ROW(
    bv.num,   
    encode(bv.hash,'hex'),
    encode(bv.prev,'hex'),
    (SELECT av.name FROM hive.accounts_view av WHERE av.id = bv.producer_account_id)::TEXT,
    encode(bv.transaction_merkle_root,'hex'),
    COALESCE(bv.extensions, '[]'),
    encode(bv.witness_signature, 'hex'),
    bv.signing_key,
    bv.hbd_interest_rate::numeric,
    bv.total_vesting_fund_hive::numeric,
    bv.total_vesting_shares::numeric,
    bv.total_reward_fund_hive::numeric,
    bv.virtual_supply::numeric,
    bv.current_supply::numeric,
    bv.current_hbd_supply::numeric,
    bv.dhf_interval_ledger::numeric,
    bv.created_at)
  FROM hive.blocks_view bv
  WHERE bv.num = __block
  );

END
$$;

RESET ROLE;
