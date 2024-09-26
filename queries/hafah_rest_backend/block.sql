SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_python.get_block_json( _block_num INT,  _include_virtual BOOLEAN = FALSE)
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block hive.block_type;
    __result JSON;
BEGIN
    SELECT * FROM hive.get_block( _block_num, _include_virtual) INTO __block;

    IF __block.timestamp IS NULL THEN
        RETURN jsonb_build_object();
    END IF;

    SELECT to_jsonb(
        hive.build_block_json(
        __block.previous,
        __block.timestamp,
        __block.witness,
        __block.transaction_merkle_root,
        __block.extensions,
        __block.witness_signature,
        __block.transactions,
        __block.block_id,
        __block.signing_key,
        __block.transaction_ids
        )
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;

RESET ROLE;
