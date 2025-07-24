SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_python.get_block_range( _block_num INT, _end_block_num INT)
    RETURNS SETOF hive.block_type
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    IF NOT _block_num  > 0 THEN
        RAISE EXCEPTION 'block-num < 0: Invalid starting block number';
    END IF;

    IF NOT (_end_block_num - _block_num + 1) > 0 THEN
        RAISE EXCEPTION 'block range < 0: negative number of blocks?';
    END IF;

    IF NOT (_end_block_num - _block_num + 1) <= 1000 THEN
        RAISE EXCEPTION 'block range > 1000: You can only ask for 1000 blocks at a time';
    END IF;

    RETURN QUERY SELECT (block).* FROM hive.get_block_from_views( _block_num, (_end_block_num - _block_num + 1));
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hafah_backend.get_block_range(_block_num INT, _end_block_num INT)
    RETURNS SETOF hafah_backend.block_range
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
  RETURN QUERY (
    SELECT
      encode( gbr.previous, 'hex')::TEXT,
      TRIM(both '"' from to_json(gbr.timestamp)::text)::timestamp,
      gbr.witness::TEXT,
      encode( gbr.transaction_merkle_root, 'hex')::TEXT,
      COALESCE(gbr.extensions, jsonb_build_array()),
      encode( gbr.witness_signature, 'hex')::TEXT,
      COALESCE(hive.transactions_to_json(gbr.transactions), jsonb_build_array()),
      encode( gbr.block_id, 'hex')::TEXT,
      gbr.signing_key::TEXT,
      (SELECT ARRAY( SELECT encode(unnest(gbr.transaction_ids), 'hex')))::TEXT[]
    FROM hafah_python.get_block_range(_block_num, _end_block_num) gbr
    WHERE gbr.timestamp IS NOT NULL
  );
END;
$BODY$
;

RESET ROLE;
