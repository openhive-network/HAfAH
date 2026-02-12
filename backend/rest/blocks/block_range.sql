SET ROLE hafah_owner;

/*
 * block_range.sql: REST API backend for block range retrieval.
 *
 * Called by: hafah_endpoints.get_blocks() in endpoints/blocks/get_blocks.sql
 *
 * REST Endpoint: GET /blocks?from-block={n}&to-block={m}
 */

/*
 * ===================================================================================
 * get_raw_block_range
 * ===================================================================================
 * PURPOSE: Internal helper to retrieve raw block data for a range of blocks.
 *          Performs validation and calls HAF's get_block_from_views.
 *
 * PARAMETERS:
 *   _block_num     - Starting block number
 *   _end_block_num - Ending block number (inclusive)
 *
 * RETURNS: Set of raw block data from HAF
 *
 * CONSTRAINTS:
 *   - Starting block must be > 0
 *   - Range must be positive
 *   - Maximum 1000 blocks per request
 *
 * DATA SOURCES:
 *   - hive.get_block_from_views(): HAF bulk block retrieval function
 *
 * NOTES:
 *   - 1000 block limit prevents memory exhaustion on large requests
 *   - Inclusive range: from-block to to-block both included
 *   - Called by get_block_range() which formats the output
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_raw_block_range( _block_num INT, _end_block_num INT)
    RETURNS SETOF hive.block_type
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    -- Validation: Block numbers are 1-indexed (genesis is block 1)
    IF NOT _block_num  > 0 THEN
        RAISE EXCEPTION 'block-num must be greater than 0: Invalid starting block number';
    END IF;

    -- Validation: End block must be >= start block (inclusive range)
    IF NOT (_end_block_num - _block_num + 1) > 0 THEN
        RAISE EXCEPTION 'block range < 0: negative number of blocks?';
    END IF;

    -- Rate limiting: Maximum 1000 blocks per request to prevent DoS
    -- Each block can contain many transactions/operations = memory concern
    IF NOT (_end_block_num - _block_num + 1) <= 1000 THEN
        RAISE EXCEPTION 'block range > 1000: You can only ask for 1000 blocks at a time';
    END IF;

    -- HAF bulk retrieval: Second param is count, not end block
    -- Returns composite type containing block + transactions + operations
    RETURN QUERY SELECT (block).* FROM hive.get_block_from_views( _block_num, (_end_block_num - _block_num + 1));
END;
$BODY$
;

/*
 * ===================================================================================
 * get_block_range
 * ===================================================================================
 * PURPOSE: Retrieve multiple blocks in a range with formatted output.
 *          Filters out blocks with NULL timestamps (non-existent blocks).
 *
 * PARAMETERS:
 *   _block_num     - Starting block number
 *   _end_block_num - Ending block number (inclusive)
 *
 * RETURNS: Set of formatted block data
 *
 * DATA SOURCES:
 *   - hafah_backend.get_raw_block_range(): Validated block retrieval
 *   - hive.transactions_to_json(): HAF transaction serializer
 *
 * NOTES:
 *   - Offset-based pagination (page-based): Returns all blocks in range
 *   - Unlike cursor-based pagination, does not track next position
 *   - Missing blocks (future or gaps) filtered by NULL timestamp check
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_block_range(_block_num INT, _end_block_num INT)
    RETURNS SETOF hafah_backend.block_range
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
  RETURN QUERY (
    SELECT
      -- Binary-to-hex: Previous block hash for chain linking
      encode( gbr.previous, 'hex')::TEXT,
      -- Timestamp formatting: Strip JSON quotes
      TRIM(both '"' from to_json(gbr.timestamp)::text)::timestamp,
      gbr.witness::TEXT,
      -- Binary-to-hex: Merkle root for transaction integrity
      encode( gbr.transaction_merkle_root, 'hex')::TEXT,
      COALESCE(gbr.extensions, jsonb_build_array()),
      -- Binary-to-hex: Witness signature (65 bytes)
      encode( gbr.witness_signature, 'hex')::TEXT,
      -- Transaction serialization: Use HAF utility for consistent format
      COALESCE(hive.transactions_to_json(gbr.transactions), jsonb_build_array()),
      -- Binary-to-hex: Block ID for unique identification
      encode( gbr.block_id, 'hex')::TEXT,
      gbr.signing_key::TEXT,
      -- Transaction IDs: Array of hashes, each encoded as hex
      (SELECT ARRAY( SELECT encode(unnest(gbr.transaction_ids), 'hex')))::TEXT[]
    FROM hafah_backend.get_raw_block_range(_block_num, _end_block_num) gbr
    -- Skip non-existent blocks: NULL timestamp = block not in database
    -- This handles requests for future blocks or sync gaps gracefully
    WHERE gbr.timestamp IS NOT NULL
  );
END;
$BODY$
;

RESET ROLE;
