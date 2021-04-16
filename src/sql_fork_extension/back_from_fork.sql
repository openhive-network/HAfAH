DROP FUNCTION IF EXISTS back_from_fork_one_table;
CREATE FUNCTION back_from_fork_one_table( _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[])
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    -- First we find rows ids with lowest block num, then delete, insert or update these rows with rows ids
    -- revert inserted rows
    EXECUTE format(
        'DELETE FROM %I
        WHERE %I.hive_rowid IN
        (
        SELECT st.hive_rowid FROM
            (
                SELECT DISTINCT ON ( st.hive_rowid ) st.hive_rowid, st.hive_operation_type
                FROM hive.%I st
                ORDER BY st.hive_rowid, st.hive_block_num
            ) as st
        WHERE st.hive_operation_type = 0
        )'
        , _table_name
        , _table_name
        , _shadow_table_name
    );

    -- revert deleted rows
    EXECUTE format(
        'INSERT INTO %I
        (
        SELECT %s FROM
            (
                SELECT DISTINCT ON ( hive_rowid ) *
                FROM hive.%I
                ORDER BY hive_rowid, hive_block_num
            ) as st
         WHERE st.hive_operation_type = 1
        )'
        , _table_name
        , array_to_string( _columns, ',' )
        , _shadow_table_name
    );

    -- update deleted rows
    -- first remove rows
    EXECUTE format(
        'DELETE FROM %I
        WHERE %I.hive_rowid IN
        (
        SELECT st.hive_rowid FROM
            (
                SELECT DISTINCT ON ( st.hive_rowid ) st.hive_rowid, st.hive_operation_type
                FROM hive.%I st
                ORDER BY st.hive_rowid, st.hive_block_num
            ) as st
        WHERE st.hive_operation_type = 2
        )'
        , _table_name
        , _table_name
        , _shadow_table_name
    );

    -- now insert old rows
    EXECUTE format(
            'INSERT INTO %I
            (
            SELECT %s FROM
                (
                    SELECT DISTINCT ON ( hive_rowid ) *
                    FROM hive.%I
                    ORDER BY hive_rowid, hive_block_num
                ) as st
             WHERE st.hive_operation_type = 2
            )'
        , _table_name
        , array_to_string( _columns, ',' )
        , _shadow_table_name
    );

    EXECUTE format( 'TRUNCATE hive.%I', _shadow_table_name );
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
    UPDATE hive.control_status SET back_from_fork = TRUE;
    SET CONSTRAINTS ALL DEFERRED;

    PERFORM
        back_from_fork_one_table( hrt.origin_table_name, hrt.shadow_table_name, hrt.origin_table_columns )
    FROM hive.registered_tables hrt ORDER BY hrt.id;

    UPDATE hive.control_status SET back_from_fork = FALSE;
END;
$BODY$
;
