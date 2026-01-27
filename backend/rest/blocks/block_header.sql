SET ROLE hafah_owner;

/*
 * block_header.sql: REST API backend for block header retrieval.
 *
 * Called by: hafah_endpoints.get_block_header() in endpoints/blocks/get_block_header.sql
 *
 * REST Endpoint: GET /blocks/{block-num}/header
 */

/*
 * ===================================================================================
 * get_block_header
 * ===================================================================================
 * PURPOSE: Retrieve block header without transactions and operations.
 *          Lightweight endpoint for header-only queries.
 *
 * PARAMETERS:
 *   _block_num - Block number to retrieve header for
 *
 * RETURNS: Block header data (previous hash, timestamp, witness, merkle root, extensions)
 *
 * DATA SOURCES:
 *   - hive.get_block_header(): HAF function returning header-only composite type
 *
 * NOTES:
 *   - Lighter than get_block() - skips transaction/operation retrieval
 *   - Useful for chain traversal, block validation, or header-only displays
 *   - Binary hashes encoded as hex for JSON transport
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_block_header( _block_num INT )
    RETURNS hafah_backend.block_header
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __block hive.block_header_type;
BEGIN
  -- Use HAF's lightweight header-only function (no transaction/op data)
  SELECT * FROM hive.get_block_header( _block_num ) INTO __block;

  -- Missing block detection: NULL timestamp means block doesn't exist
  IF __block.timestamp IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN (
    -- Binary-to-hex: Previous block hash (32 bytes) links blocks in chain
    encode( __block.previous, 'hex') :: TEXT,
    -- Timestamp formatting: Strip JSON quotes for clean timestamp
    TRIM(both '"' from to_json(__block.timestamp)::text),
    __block.witness,
    -- Binary-to-hex: Merkle root proves transaction integrity
    encode( __block.transaction_merkle_root, 'hex'),
    -- Extensions: Protocol upgrades/features, empty array if none
    COALESCE(__block.extensions, jsonb_build_array())
  )::hafah_backend.block_header;

END;
$BODY$
;

RESET ROLE;
