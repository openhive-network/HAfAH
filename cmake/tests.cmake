MACRO( ADD_UNIT_TESTS module_name)
    SET( test_target unit.${module_name} )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    MESSAGE( STATUS "TEST sources : ${sources}" )
    ADD_EXECUTABLE( ${test_target} ${sources} )

    SETUP_COMPILER( ${test_target} )
    ADD_POSTGRES_INCLUDES( ${test_target} )

    ADD_BOOST_LIBRARIES( ${test_target} )

    ADD_POSTGRES_LIBRARIES( ${test_target} )
    TARGET_LINK_LIBRARIES( ${test_target} PRIVATE test_${module_name} )
    TARGET_LINK_LIBRARIES( ${test_target} PRIVATE gmock )


    ADD_TEST( NAME test.${test_target} COMMAND ${test_target} )
    MESSAGE( STATUS "Added unit tests '${test_target}'" )
ENDMACRO()