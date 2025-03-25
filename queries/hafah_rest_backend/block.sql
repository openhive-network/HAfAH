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

RESET ROLE;
