MACRO( ADD_FUNCTIONAL_TESTS test_name sql_test_path)
    SET( test_target test.functional.fork_extension.${test_name} )
    ADD_TEST( NAME ${test_target}
            COMMAND test.sh ${sql_test_path}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

ADD_FUNCTIONAL_TESTS( back_from_fork_inserts back_from_fork_inserts.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_updates back_from_fork_update.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_insert_updates_deletes back_from_fork_insert_update_delete.sql )
ADD_FUNCTIONAL_TESTS( back_from_fork_3_tables back_from_fork_3_tables.sql )
# ADD_FUNCTIONAL_TESTS( saved_tuples_rollback saved_tuples_rollback.sql ) # pq copy does not fall in current transaction
