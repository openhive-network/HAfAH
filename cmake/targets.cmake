MACRO( ADD_RUNTIME_LOADED_LIB target_name sources )
    MESSAGE( INFO ${sources})
    ADD_LIBRARY( ${target_name} SHARED ${sources} )

    SETUP_COMPILER( ${target_name} )

    ADD_BOOST_LIBRARIES( ${target_name} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )
ENDMACRO()