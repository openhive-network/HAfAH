DROP FUNCTION IF EXISTS back_from_fork_one_table;
CREATE FUNCTION back_from_fork_one_table( _table_name TEXT, _shadow_table_name TEXT)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    RAISE NOTICE 'INSIDE REMOVE %, %',  _table_name, _shadow_table_name;
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
    PERFORM
        back_from_fork_one_table( hrt.origin_table_name, hrt.shadow_table_name )
    FROM hive_registered_tables hrt;
END;
$BODY$
;
