CREATE OR REPLACE FUNCTION hafah_python.get_block_range( _block_num INT, _end_block_num INT)
    RETURNS SETOF hive.block_type
    LANGUAGE plpgsql
    VOLATILE
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

CREATE OR REPLACE FUNCTION hafah_python.get_block_range_json( _block_num INT, _end_block_num INT)
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'blocks', COALESCE(array_agg(
            hive.build_block_json(
                gbr.previous,
                gbr.timestamp,
                gbr.witness,
                gbr.transaction_merkle_root,
                gbr.extensions,
                gbr.witness_signature,
                gbr.transactions,
                gbr.block_id,
                gbr.signing_key,
                gbr.transaction_ids
            )
        ), ARRAY[]::JSONB[] )
    ) INTO __result FROM hafah_python.get_block_range( _block_num , _end_block_num) gbr
    WHERE gbr.timestamp IS NOT NULL;
    RETURN __result;
END;
$BODY$;
