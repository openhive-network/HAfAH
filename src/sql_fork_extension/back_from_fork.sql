DROP FUNCTION IF EXISTS back_from_fork_one_table;
CREATE FUNCTION back_from_fork_one_table( _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[])
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- revert inserted rows
    EXECUTE format(
        'DELETE FROM %I
        WHERE %I.hive_rowid IN
        (
            SELECT DISTINCT ON ( st.hive_rowid ) st.hive_rowid
            FROM %I st
            WHERE st.hive_operation_type = 0
            ORDER BY st.hive_rowid, st.hive_block_num
        )'
        , _table_name
        , _table_name
        , _shadow_table_name
    );

    -- revert deleted rows
    EXECUTE format(
            'INSERT INTO %I
        (
            SELECT DISTINCT ON ( hive_rowid ) %s
            FROM %I
            WHERE hive_operation_type = 1
            ORDER BY hive_rowid, hive_block_num
        )'
        , _table_name
        , array_to_string( _columns, ',' )
        , _shadow_table_name
    );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive_back_from_fork;
CREATE FUNCTION hive_back_from_fork()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hive_control_status SET back_from_fork = TRUE;

    PERFORM
        back_from_fork_one_table( hrt.origin_table_name, hrt.shadow_table_name, hrt.origin_table_columns )
    FROM hive_registered_tables hrt;

    UPDATE hive_control_status SET back_from_fork = FALSE;
END;
$BODY$
;
