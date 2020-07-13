# Adding python tests to cmake
set(REFERENCE_NODE https://api.hive.blog CACHE STRING "Address of reference node for api tests")
set(TEST_NODE http://127.0.0.1:8090 CACHE STRING "Address of node under api tests")

configure_file("${CMAKE_CURRENT_LIST_DIR}/testbase.py" "${CMAKE_BINARY_DIR}/tests/api_tests/testbase.py" COPYONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/jsonsocket.py" "${CMAKE_BINARY_DIR}/tests/api_tests/jsonsocket.py" COPYONLY)

# @common_working_dir - the root of working directories for all the api test
# @directory_with_test - full path to tests_api repo on the disk
# @product - hived or hivemind
macro(ADD_API_TEST common_working_dir directory_with_test product api_name test_name)
    set(working_dir ${CMAKE_BINARY_DIR}/tests)
    set(api_test_directory ${directory_with_test}/${product}/reference/${api_name})
    set(test_script_path ${api_test_directory}/${test_name}.py)
    message(STATUS "Adding ${api_name}/${test_name} to test list")
    set(extra_macro_args ${ARGN})
    list(LENGTH extra_macro_args num_extra_args)
    set(test_parameters ${test_script_path} ${TEST_NODE} ${REFERENCE_NODE} ${working_dir})
    if (${num_extra_args} GREATER 0)
        set(test_parameters ${test_script_path} ${TEST_NODE} ${REFERENCE_NODE} ${working_dir} ${extra_macro_args})
    endif()
    set(test "api/reference/${api_name}/${test_name}")
    add_test(NAME "${test}" COMMAND python3 ${test_parameters} WORKING_DIRECTORY ${working_dir})
    set_property(TEST ${test} PROPERTY LABELS api_reference_tests)
endmacro(ADD_API_TEST)

# @common_working_dir - the root of working directories for all the api test
# @directory_with_test - full path to tests_api repo on the disk
# @product - hived or hivemind
# @blocks - number of synchronized blocks
# @api_name - full api name i.e. condenser_api
macro(ADD_API_PYREST_TEST common_working_dir directory_with_test product blocks api_name)
    # set(working_dir ${CMAKE_BINARY_DIR}/tests)
    set( pyrest_tests_subdir "pyrest_tests" )
    set(working_dir ${directory_with_test}/${product}/${pyrest_tests_subdir})
    set(test_file_path ${directory_with_test}/${product}/${pyrest_tests_subdir}/${blocks}/${api_name}/${api_name}_test.yaml)
    set(api_test_directory ${directory_with_test}/${product}/${pyrest_tests_subdir}/${api_name})
    set(test_name "api/pyresttests/${blocks}/${api_name}")
    message(STATUS "Adding ${test_name}" )
    set(test_parameters ${test_file_path} "--import_extensions=validator_ex\;comparator_equal")
    add_test(NAME ${test_name} COMMAND pyresttest ${TEST_NODE} ${test_parameters} WORKING_DIRECTORY ${working_dir})
    set_property(TEST ${test_name} PROPERTY LABELS "pyresttests")
endmacro(ADD_API_PYREST_TEST)

# @directory_with_test - full path to tests_api repo on the disk
# @product - hived or hivemind
macro(ADD_API_SMOKETEST directory_with_test product)
    ADD_TEST(NAME "api/smoketes" COMMAND ${directory_with_test}/${product}/api_error_smoketest.py ${TEST_NODE} WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/tests)
endmacro(ADD_API_SMOKETEST)