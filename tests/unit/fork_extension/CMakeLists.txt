ADD_UNIT_TESTS( fork_extension )

TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/fork_extension/. ${CMAKE_SOURCE_DIR}/src/psql_utils/. )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE mock )