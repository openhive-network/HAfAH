SET ROLE hafah_owner;

/*
 * block.sql: REST API backend for single block retrieval.
 *
 * Called by: hafah_endpoints.get_block() in endpoints/blocks/get_block.sql
 *
 * REST Endpoints:
 *   - GET /blocks/{block-num}
 *   - GET /blocks/{block-num}/raw (global state)
 */

/*
 * ===================================================================================
 * get_block
 * ===================================================================================
 * PURPOSE: Retrieve full block data including transactions and operations.
 *
 * PARAMETERS:
 *   _block_num       - Block number to retrieve
 *   _include_virtual - Whether to include virtual operations (default FALSE)
 *
 * RETURNS: Block data with transactions, operations, and metadata
 *
 * DATA SOURCES:
 *   - hive.get_block(): HAF composite function returning full block data
 *   - hive.transactions_to_json(): HAF utility for transaction serialization
 *
 * NOTES:
 *   - Binary data (hashes, signatures) encoded as hex strings for JSON safety
 *   - NULL timestamp indicates block doesn't exist in HAF database
 *   - Virtual operations are blockchain-generated (rewards, vesting, etc.)
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_block(_block_num INT,  _include_virtual BOOLEAN = FALSE)
    RETURNS hafah_backend.block_range
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __block hive.block_type;
BEGIN
  -- Use HAF's get_block function which aggregates block, transactions, and operations
  SELECT * FROM hive.get_block( _block_num, _include_virtual) INTO __block;

  -- Missing block detection: NULL timestamp means block doesn't exist
  -- This can happen if requesting a future block or during sync
  IF __block.timestamp IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN (
    -- Binary-to-hex encoding: Previous block hash (32 bytes) as hex string
    encode( __block.previous, 'hex')::TEXT,
    -- Timestamp formatting: Remove JSON quotes for clean timestamp value
    TRIM(both '"' from to_json(__block.timestamp)::text)::timestamp,
    __block.witness::TEXT,
    -- Merkle root: Binary hash of all transactions encoded as hex
    encode( __block.transaction_merkle_root, 'hex')::TEXT,
    -- Extensions: Blockchain protocol extensions, empty array if none
    COALESCE(__block.extensions, jsonb_build_array()),
    -- Witness signature: Block producer's signature (65 bytes) as hex
    encode( __block.witness_signature, 'hex')::TEXT,
    -- Transactions: Use HAF utility to serialize transaction array to JSON
    COALESCE(hive.transactions_to_json(__block.transactions), jsonb_build_array()),
    -- Block ID: Unique identifier (32 bytes) as hex for API consumers
    encode( __block.block_id, 'hex')::TEXT,
    __block.signing_key::TEXT,
    -- Transaction IDs: Array of transaction hashes, each encoded as hex
    (SELECT ARRAY( SELECT encode(unnest(__block.transaction_ids), 'hex')))::TEXT[]
  )::hafah_backend.block_range;

END;
$BODY$
;

/*
 * ===================================================================================
 * get_global_state
 * ===================================================================================
 * PURPOSE: Retrieve block data with global blockchain state at that block.
 *          Includes economic data like vesting fund, supply, and HBD interest rate.
 *
 * PARAMETERS:
 *   _block_num - Block number to retrieve state for
 *
 * RETURNS: Block with global state data
 *
 * DATA SOURCES:
 *   - hive.blocks_view: Block headers with embedded economic state
 *   - hive.accounts_view: Witness name lookup from producer_account_id
 *
 * NOTES:
 *   - Global state snapshot captured at each block for economic queries
 *   - Supply values stored as TEXT to preserve precision (asset format)
 *   - Used by REST /blocks/{block-num}/raw endpoint
 */
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
      -- Binary-to-hex: Block hash (32 bytes) as hex string
      encode(bv.hash,'hex'),
      -- Binary-to-hex: Previous block hash (32 bytes) as hex string
      encode(bv.prev,'hex'),
      -- Witness lookup: Convert producer_account_id to readable name
      (SELECT av.name FROM hive.accounts_view av WHERE av.id = bv.producer_account_id)::TEXT,
      -- Binary-to-hex: Merkle root of all transactions
      encode(bv.transaction_merkle_root,'hex'),
      COALESCE(bv.extensions, '[]'),
      -- Binary-to-hex: Witness signature (65 bytes) as hex string
      encode(bv.witness_signature, 'hex'),
      bv.signing_key,
      -- Economic state: HBD interest rate at this block
      bv.hbd_interest_rate::numeric,
      -- Economic state: Total HIVE locked in vesting (staked)
      bv.total_vesting_fund_hive::TEXT,
      -- Economic state: Total vesting shares (VESTS)
      bv.total_vesting_shares::TEXT,
      -- Economic state: Reward fund for content creators
      bv.total_reward_fund_hive::TEXT,
      -- Economic state: Virtual supply including HBD conversions
      bv.virtual_supply::TEXT,
      -- Economic state: Current circulating HIVE supply
      bv.current_supply::TEXT,
      -- Economic state: Current HBD supply
      bv.current_hbd_supply::TEXT,
      -- Economic state: DHF (proposal) fund balance
      bv.dhf_interval_ledger::numeric,
      bv.created_at
    )::hafah_backend.block
    FROM hive.blocks_view bv
    WHERE bv.num = _block_num
  );

  -- Missing block detection: NULL block_num means no matching row
  IF __block_type.block_num IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN __block_type;
END;
$BODY$
;

RESET ROLE;
