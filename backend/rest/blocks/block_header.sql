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
  SELECT * FROM hive.get_block_header( _block_num ) INTO __block;

  IF __block.timestamp IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;

  RETURN (
    encode( __block.previous, 'hex') :: TEXT,
    TRIM(both '"' from to_json(__block.timestamp)::text),
    __block.witness,
    encode( __block.transaction_merkle_root, 'hex'),
    COALESCE(__block.extensions, jsonb_build_array())
  )::hafah_backend.block_header;

END;
$BODY$
;

RESET ROLE;
