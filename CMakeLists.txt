include(common/api_tests.cmake)

ENABLE_TESTING()

IF ( BUILD_HIVE_TESTNET )
    add_subdirectory(unit)
    add_subdirectory(hived/hive_functional)
ELSE ( BUILD_HIVE_TESTNET )
    add_subdirectory(hived/api_tests)
ENDIF ( BUILD_HIVE_TESTNET )