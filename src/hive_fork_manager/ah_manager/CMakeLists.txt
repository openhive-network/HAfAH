PROJECT(ah_manager)

ADD_SUBDIRECTORY( protocol )

ADD_LIBRARY(  ah_manager
              utilities.cpp
              )

target_link_libraries( ah_manager PUBLIC hive_protocol )


if( CLANG_TIDY_EXE )
   set_target_properties(
    ah_manager PROPERTIES
      CXX_CLANG_TIDY "${DO_CLANG_TIDY}"
   )
endif( CLANG_TIDY_EXE )

install( TARGETS
  ah_manager

  RUNTIME DESTINATION bin
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)

