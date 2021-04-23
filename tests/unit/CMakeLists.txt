ADD_SUBDIRECTORY( googletest )

INCLUDE_DIRECTORIES( ${CMAKE_SOURCE_DIR}/tests/unit/googletest/googlemock/include )
INCLUDE_DIRECTORIES( ${CMAKE_SOURCE_DIR}/tests/unit/googletest/googletest/include )

ADD_SUBDIRECTORY( mockups )

ADD_SUBDIRECTORY( psql_utils )
ADD_SUBDIRECTORY( pq_utils )