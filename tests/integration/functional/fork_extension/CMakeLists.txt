MACRO( ADD_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_1})
    SET( test_target test.functional.fork_extension.${test_name} )
    ADD_TEST( NAME ${test_target}
            COMMAND test.sh ${sql_test_path}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

ADD_FUNCTIONAL_TESTS( back_from_fork_inserts.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_update.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_insert_update_delete.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_3_tables.sql )
# ADD_FUNCTIONAL_TESTS( saved_tuples_rollback.sql ) # pq copy does not fall in current transaction
# ADD_FUNCTIONAL_TESTS( back_from_fork_fkey.sql ) # defferable PK cannot be referenced as FK
ADD_FUNCTIONAL_TESTS( back_from_fork_constraints.sql )
ADD_FUNCTIONAL_TESTS( on_table_changed_inserts.sql )
ADD_FUNCTIONAL_TESTS( on_table_changed_update.sql )
ADD_FUNCTIONAL_TESTS( on_table_changed_delete.sql )
ADD_FUNCTIONAL_TESTS( on_table_changed_truncate.sql )

ADD_FUNCTIONAL_TESTS( performance_insert_rows_test.sql )
ADD_FUNCTIONAL_TESTS( performance_back_from_insert_rows_test.sql )
ADD_FUNCTIONAL_TESTS( performance_delete_rows_test.sql )
ADD_FUNCTIONAL_TESTS( performance_back_from_delete_rows_test.sql )