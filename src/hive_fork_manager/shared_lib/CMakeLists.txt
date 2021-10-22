#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

#fc settings
SET(DEFAULT_LIBRARY_INSTALL_DIR ${POSTGRES_LIBDIR} CACHE PATH "DEFAULT LIBRARY" FORCE)
SET( DONT_INSTALL_LIBRARY OFF )

SET( target_name hfm-${GIT_VER_DEC} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE "${PROJECT_SOURCE_DIR}/src/protocol/include" )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol )

INSTALL( TARGETS
  ${target_name}

  RUNTIME DESTINATION bin
  LIBRARY DESTINATION ./
  ARCHIVE DESTINATION lib
)

