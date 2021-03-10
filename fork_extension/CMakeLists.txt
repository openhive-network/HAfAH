SET( target_name fork_extension )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

INSTALL( TARGETS ${target_name} DESTINATION ${POSTGRES_LIBDIR}/plugins )