
SET( BUILD_SHARED_LIBS ON FORCE )

ADD_SUBDIRECTORY( protocol )

SET( target_name ah_manager )

PREPARE_LIB( ${target_name} )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol )

INSTALL( TARGETS ${target_name} DESTINATION ${POSTGRES_LIBDIR}/plugins OPTIONAL )
