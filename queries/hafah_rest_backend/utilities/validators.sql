SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.validate_participation_mode(_mode hafah_backend.participation_mode, _account_name TEXT)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  IF _mode = 'all' AND _account_name IS NOT NULL THEN
    RAISE EXCEPTION 'For participation mode ''all'', account name should not be provided';
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.validate_account(_account_id INT, _account_name TEXT, _required BOOLEAN)
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  IF (_required AND _account_id IS NULL) OR (NOT _required AND _account_name IS NOT NULL AND _account_id IS NULL) THEN
    PERFORM hafah_backend.rest_raise_missing_account(_account_name);
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.validate_operation_types(_operations INT[], _allowed_operations INT[])
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  IF (NOT _operations <@ _allowed_operations) AND _operations IS NOT NULL THEN
    PERFORM hafah_backend.rest_raise_invalid_operation_types(_allowed_operations);
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.validate_block_num(_block_num INT)
RETURNS VOID
LANGUAGE 'plpgsql'
STABLE
AS
$$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hive.blocks_view bv WHERE bv.num = _block_num) THEN
    PERFORM hafah_backend.rest_raise_missing_block(_block_num);
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.validate_op_type_id(_op_type INT)
RETURNS VOID
LANGUAGE 'plpgsql'
STABLE
AS
$$
BEGIN
  IF (_op_type > (SELECT MAX(id) FROM hafd.operation_types)) OR _op_type < 0 THEN
    PERFORM hafah_backend.rest_raise_missing_op_type(_op_type);
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.validate_operation_id(_operation_id BIGINT)
RETURNS VOID
LANGUAGE 'plpgsql'
STABLE
AS
$$
BEGIN
  IF (SELECT ov.block_num FROM hive.operations_view ov WHERE ov.id = _operation_id) IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_operation_id(_operation_id);
  END IF;
END
$$
;

RESET ROLE;
