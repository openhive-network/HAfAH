MACRO( ADD_SQL_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_1})
    SET( test_target test.functional.sql_fork_extension.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/sql_fork_extension )
    ADD_TEST( NAME ${test_target}
            COMMAND test.sh ${sources_under_tests_path} ${sql_test_path}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

ADD_SQL_FUNCTIONAL_TESTS( schema_test.sql )

ADD_SQL_FUNCTIONAL_TESTS( register_table_test.sql )
ADD_SQL_FUNCTIONAL_TESTS( register_not_empty_table_test.sql )

ADD_SQL_FUNCTIONAL_TESTS( create_context_test.sql )
ADD_SQL_FUNCTIONAL_TESTS( context_next_block_test.sql )

ADD_SQL_FUNCTIONAL_TESTS( trigger_on_insert_test.sql )
ADD_SQL_FUNCTIONAL_TESTS( trigger_on_delete_test.sql )
ADD_SQL_FUNCTIONAL_TESTS( trigger_on_update_test.sql )

ADD_SQL_FUNCTIONAL_TESTS( back_from_fork_insert_test.sql )
ADD_SQL_FUNCTIONAL_TESTS( back_from_fork_delete_test.sql )