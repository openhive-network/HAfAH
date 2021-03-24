SET( target_name fork_extension )

ADD_RUNTIME_LOADED_LIB( ${target_name} )
TARGET_LINK_LIBRARIES( ${target_name} PRIVATE psql_utils )

INSTALL( TARGETS ${target_name} DESTINATION ${POSTGRES_LIBDIR}/plugins )