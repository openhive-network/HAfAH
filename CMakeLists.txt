include(common/api_tests.cmake)

ENABLE_TESTING()

add_subdirectory(unit)
add_subdirectory(hived/api_tests)
add_subdirectory(hived/hive_functional)