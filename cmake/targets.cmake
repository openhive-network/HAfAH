MACRO( ADD_RUNTIME_LOADED_LIB target_name sources )
    MESSAGE( INFO ${sources})
    ADD_LIBRARY( ${target_name} SHARED ${sources} )

    TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE "." )

    ADD_BOOST_LIBRARIES( ${target_name} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )
ENDMACRO()