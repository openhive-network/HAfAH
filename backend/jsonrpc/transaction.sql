SET ROLE hafah_owner;

DROP TYPE IF EXISTS hafah_backend.get_transaction_result CASCADE;
CREATE TYPE hafah_backend.get_transaction_result AS ( _ref_block_num INT, _ref_block_prefix BIGINT, _expiration TEXT, _block_num INT, _trx_in_block SMALLINT, _signature TEXT, _multisig_number SMALLINT );

CREATE OR REPLACE FUNCTION hafah_backend.get_transaction( in _trx_hash BYTEA, in _include_reversible BOOLEAN )
RETURNS SETOF hafah_backend.get_transaction_result
AS
$function$
DECLARE
  __result hive.transactions_view%ROWTYPE;
  __multisig_number SMALLINT;
BEGIN

  SELECT * INTO __result FROM hive.transactions_view ht WHERE ht.trx_hash = _trx_hash;
  IF NOT _include_reversible AND __result.block_num > hive.app_get_irreversible_block(  ) THEN
    RETURN QUERY SELECT
      NULL::INT,
      NULL::BIGINT,
      NULL::TEXT,
      NULL::INT,
      NULL::SMALLINT,
      NULL::TEXT,
      NULL::SMALLINT
    LIMIT 0;
    RETURN;
  END IF;

  SELECT count(*) INTO __multisig_number FROM hive.transactions_multisig_view htm WHERE htm.trx_hash = _trx_hash;

  RETURN QUERY
    SELECT
      __result.ref_block_num _ref_block_num,
      __result.ref_block_prefix _ref_block_prefix,
      trim(both '"' from to_json(__result.expiration)::text) _expiration,
      __result.block_num _block_num,
      __result.trx_in_block _trx_in_block,
      encode(__result.signature, 'hex') _signature,
      __multisig_number;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.get_multi_signatures_in_transaction( in _trx_hash BYTEA )
RETURNS TABLE(
    _signature TEXT
)
AS
$function$
BEGIN

  RETURN QUERY
    SELECT
      encode(htm.signature, 'hex') _signature
    FROM hive.transactions_multisig_view htm
    WHERE htm.trx_hash = _trx_hash;
END
$function$
language plpgsql STABLE;

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_in_transaction( in _block_num INT, in _trx_in_block INT, in _is_legacy_style BOOLEAN, in _include_virtual BOOLEAN = FALSE)
RETURNS TABLE(
    _value TEXT
)
AS
$function$
BEGIN
  RETURN QUERY
    SELECT
      (
        CASE
          WHEN _is_legacy_style THEN hive.get_legacy_style_operation(ho.body_binary)::text
          ELSE ho.body :: text
        END
      ) AS _value
    FROM hive.operations_view ho
    JOIN hafd.operation_types hot ON ho.op_type_id = hot.id
    WHERE ho.block_num = _block_num AND ho.trx_in_block = _trx_in_block AND (_include_virtual OR hot.is_virtual = FALSE)
    ORDER BY ho.id;
END
$function$
language plpgsql STABLE;

RESET ROLE;
