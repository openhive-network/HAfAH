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
    set(api_test_directory ${directory_with_test}/${product}/${api_name})
    set(test_script_path ${api_test_directory}/${test_name}.py)
    message(STATUS "Adding ${api_name}/${test_name} to test list")
    set(extra_macro_args ${ARGN})
    list(LENGTH extra_macro_args num_extra_args)
    set(test_parameters ${test_script_path} ${TEST_NODE} ${REFERENCE_NODE} ${working_dir})
    if (${num_extra_args} GREATER 0)
        set(test_parameters ${test_script_path} ${TEST_NODE} ${REFERENCE_NODE} ${working_dir} ${extra_macro_args})
    endif()
    add_test(NAME "api/${api_name}/${test_name}" COMMAND python3 ${test_parameters} WORKING_DIRECTORY ${working_dir})
    set_property(TEST "api/${api_name}/${test_name}" PROPERTY LABELS python_tests ${api_name} ${test_name})
endmacro(ADD_API_TEST)