MACRO( ADD_UNIT_TESTS module_name)
    SET( test_target unit.${module_name} )
    FILE( GLOB sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_EXECUTABLE( ${test_target} ${sources} )

    SETUP_COMPILER( ${test_target} )

    ADD_BOOST_LIBRARIES( ${test_target} )

    ADD_TEST( NAME test.${test_target} COMMAND ${test_target} )
    MESSAGE( STATUS "Added unit tests '${test_target}'" )
ENDMACRO()