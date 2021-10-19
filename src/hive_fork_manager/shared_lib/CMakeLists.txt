#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET(_CUSTOM_RUNTIME_PATH ${POSTGRES_LIBDIR} CACHE PATH "Custom runtime path")

set(CMAKE_INSTALL_RPATH ${_CUSTOM_RUNTIME_PATH})
SET(CMAKE_INSTALL_PREFIX ${_CUSTOM_RUNTIME_PATH} CACHE PATH "Default prefix" FORCE)

#fc settings
SET(DEFAULT_LIBRARY_INSTALL_DIR ${_CUSTOM_RUNTIME_PATH} CACHE PATH "Default library" FORCE)
SET( DONT_INSTALL_LIBRARY OFF )

SET( target_name hfm )

include_directories( "${CMAKE_SOURCE_DIR}/src/protocol/include" )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol )

INSTALL( TARGETS
  ${target_name}

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION ./
   ARCHIVE DESTINATION lib
)

