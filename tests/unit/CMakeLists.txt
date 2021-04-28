ExternalProject_Add(
        googletest
        PREFIX "${CMAKE_BINARY_DIR}/googletest"
        GIT_REPOSITORY https://github.com/google/googletest.git
        INSTALL_DIR "${CMAKE_BINARY_DIR}"
        CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}"
)



INCLUDE_DIRECTORIES( ${CMAKE_BINARY_DIR}/googletest/src/googletest/googlemock/include )
INCLUDE_DIRECTORIES( ${CMAKE_BINARY_DIR}/googletest/src/googletest/googletest/include )

ADD_SUBDIRECTORY( mockups )

ADD_SUBDIRECTORY( psql_utils )
ADD_SUBDIRECTORY( pq_utils )