SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.is_block_missing(_block_num INT, _name TEXT DEFAULT 'block-num')
RETURNS VOID
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  IF _block_num IS NULL THEN
    PERFORM hafah_backend.rest_raise_missing_arg(_name);
  END IF;
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.is_path_filter_not_empty(_path_filter TEXT[])
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RETURN (_path_filter IS NOT NULL AND _path_filter != '{}');
END
$$
;

CREATE OR REPLACE FUNCTION hafah_backend.get_group_type(_group_type hafah_backend.operation_group_types)
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
IMMUTABLE
AS
$$
BEGIN
  RETURN (
    CASE 
      WHEN _group_type = 'real' THEN 
        FALSE 
      WHEN _group_type = 'virtual' THEN 
        TRUE 
      ELSE 
        NULL 
    END
  );
END
$$
;

RESET ROLE;
