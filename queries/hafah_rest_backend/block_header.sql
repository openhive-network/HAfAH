SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_python.get_block_header_json( _block_num INT )
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block hive.block_header_type;
    __result JSON;
BEGIN

    SELECT * FROM hive.get_block_header( _block_num ) INTO __block;

    IF __block.timestamp IS NULL THEN
        RETURN jsonb_build_object();
    END IF;

    SELECT jsonb_build_object(
        'previous', encode( __block.previous, 'hex') :: TEXT,
        'timestamp', TRIM(both '"' from to_json(__block.timestamp)::text),
        'witness', __block.witness,
        'transaction_merkle_root', encode( __block.transaction_merkle_root, 'hex'),
        'extensions', COALESCE(__block.extensions, jsonb_build_array())
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;

RESET ROLE;
