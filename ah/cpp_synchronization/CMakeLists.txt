
add_executable( haf_ah main.cpp )

FIND_LIBRARY(PQXX_LIB pqxx)

if( UNIX AND NOT APPLE )
  set(rt_library rt )
endif()

find_package( Gperftools QUIET )
if( GPERFTOOLS_FOUND )
    message( STATUS "Found gperftools; compiling haf_ah with TCMalloc")
    list( APPEND PLATFORM_SPECIFIC_LIBS tcmalloc )
endif()

TARGET_INCLUDE_DIRECTORIES( haf_ah PRIVATE "${CMAKE_SOURCE_DIR}/haf/common_includes/include" )

if( HIVE_STATIC_BUILD )
   target_link_libraries( haf_ah PRIVATE
      "-static-libstdc++ -static-libgcc"
      hive_chain
      hive_protocol
      transaction_controllers
      ${PQXX_LIB}
      ${CMAKE_DL_LIBS}
      ${PLATFORM_SPECIFIC_LIBS}
      ${BROTLI_LIBRARIES}
   )
else( HIVE_STATIC_BUILD )
   target_link_libraries( haf_ah PRIVATE
      hive_chain
      hive_protocol
      transaction_controllers
      ${PQXX_LIB}
      ${CMAKE_DL_LIBS}
      ${PLATFORM_SPECIFIC_LIBS}
      ${BROTLI_LIBRARIES}
   )
endif( HIVE_STATIC_BUILD )

if( CLANG_TIDY_EXE )
   set_target_properties(
    haf_ah PROPERTIES
      CXX_CLANG_TIDY "${DO_CLANG_TIDY}"
   )
endif( CLANG_TIDY_EXE )

install( TARGETS
haf_ah
  RUNTIME DESTINATION bin
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)
