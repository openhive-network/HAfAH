DROP FUNCTION IF EXISTS hive.back_from_fork_one_table;
CREATE FUNCTION hive.back_from_fork_one_table( _table_schema TEXT, _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[], _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __columns TEXT = array_to_string( _columns, ',' );
BEGIN
    -- First we find rows ids with lowest block num, then delete, insert or update these rows with rows ids
    -- revert inserted rows
    EXECUTE format(
        'DELETE FROM %I.%I
        WHERE %I.hive_rowid IN
        (
        SELECT st.hive_rowid FROM
            (
                SELECT DISTINCT ON ( st.hive_rowid ) st.hive_rowid, st.hive_operation_type
                FROM hive.%I st
                WHERE st.hive_block_num > %s
                ORDER BY st.hive_rowid, st.hive_block_num
            ) as st
        WHERE st.hive_operation_type = 0
        )'
        , _table_schema
        , _table_name
        , _table_name
        , _shadow_table_name
        , _block_num_before_fork
    );

    -- revert deleted rows
    EXECUTE format(
        'INSERT INTO %I.%I( %s )
        (
        SELECT %s FROM
            (
                SELECT DISTINCT ON ( hive_rowid ) *
                FROM hive.%I st
                WHERE st.hive_block_num > %s
                ORDER BY st.hive_rowid, st.hive_block_num
            ) as st
         WHERE st.hive_operation_type = 1
        )'
        , _table_schema
        , _table_name
        , __columns
        , __columns
        , _shadow_table_name
        , _block_num_before_fork
    );

    -- update deleted rows
    -- first remove rows
    EXECUTE format(
        'DELETE FROM %I.%I
        WHERE %I.hive_rowid IN
        (
        SELECT st.hive_rowid FROM
            (
                SELECT DISTINCT ON ( st.hive_rowid ) st.hive_rowid, st.hive_operation_type
                FROM hive.%I st
                WHERE st.hive_block_num > %s
                ORDER BY st.hive_rowid, st.hive_block_num
            ) as st
        WHERE st.hive_operation_type = 2
        )'
        , _table_schema
        , _table_name
        , _table_name
        , _shadow_table_name
        , _block_num_before_fork
    );

    -- now insert old rows
    EXECUTE format(
            'INSERT INTO %I.%I( %s )
            (
            SELECT %s FROM
                (
                    SELECT DISTINCT ON ( hive_rowid ) *
                    FROM hive.%I st
                    WHERE st.hive_block_num > %s
                    ORDER BY hive_rowid, hive_block_num
                ) as st
             WHERE st.hive_operation_type = 2
            )'
        , _table_schema
        , _table_name
        , __columns
        , __columns
        , _shadow_table_name
        , _block_num_before_fork
    );

    -- remove rows from shadow table
    EXECUTE format( 'DELETE FROM hive.%I st WHERE st.hive_block_num > %s', _shadow_table_name, _block_num_before_fork );
END;
$BODY$
;

