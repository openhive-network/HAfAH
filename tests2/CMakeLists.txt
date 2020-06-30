include(common/api_tests.cmake)

ENABLE_TESTING()

IF ( BUILD_HIVE_TESTNET )
    add_subdirectory(unit)
    add_subdirectory(functional)
ELSE ( BUILD_HIVE_TESTNET )
    add_subdirectory(api_tests)
ENDIF ( BUILD_HIVE_TESTNET )