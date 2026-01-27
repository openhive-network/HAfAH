SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_block(_block_num INT,  _include_virtual BOOLEAN = FALSE)
    RETURNS hafah_backend.block_range
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __block hive.block_type;
BEGIN
  SELECT * FROM hive.get_block( _block_num, _include_virtual) INTO __block;

  IF __block.timestamp IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN (
    encode( __block.previous, 'hex')::TEXT,
    TRIM(both '"' from to_json(__block.timestamp)::text)::timestamp,
    __block.witness::TEXT,
    encode( __block.transaction_merkle_root, 'hex')::TEXT,
    COALESCE(__block.extensions, jsonb_build_array()),
    encode( __block.witness_signature, 'hex')::TEXT,
    COALESCE(hive.transactions_to_json(__block.transactions), jsonb_build_array()),
    encode( __block.block_id, 'hex')::TEXT,
    __block.signing_key::TEXT,
    (SELECT ARRAY( SELECT encode(unnest(__block.transaction_ids), 'hex')))::TEXT[]
  )::hafah_backend.block_range;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hafah_backend.get_global_state(_block_num INT)
    RETURNS hafah_backend.block
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
  __block_type hafah_backend.block;
BEGIN
  __block_type := (
    SELECT (
      bv.num,   
      encode(bv.hash,'hex'),
      encode(bv.prev,'hex'),
      (SELECT av.name FROM hive.accounts_view av WHERE av.id = bv.producer_account_id)::TEXT,
      encode(bv.transaction_merkle_root,'hex'),
      COALESCE(bv.extensions, '[]'),
      encode(bv.witness_signature, 'hex'),
      bv.signing_key,
      bv.hbd_interest_rate::numeric,
      bv.total_vesting_fund_hive::TEXT,
      bv.total_vesting_shares::TEXT,
      bv.total_reward_fund_hive::TEXT,
      bv.virtual_supply::TEXT,
      bv.current_supply::TEXT,
      bv.current_hbd_supply::TEXT,
      bv.dhf_interval_ledger::numeric,
      bv.created_at
    )::hafah_backend.block
    FROM hive.blocks_view bv
    WHERE bv.num = _block_num
  );

  IF __block_type.block_num IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN __block_type;
END;
$BODY$
;

RESET ROLE;
