CMAKE_MINIMUM_REQUIRED( VERSION 3.2 )

SET( CMAKE_POSITION_INDEPENDENT_CODE ON )

SET( PROGRAM_NAME fork_extension )
SET( SOURCES
        postgres_common.cpp
        trigger.cpp
        back_from_fork.cpp
        pq/db_client.cpp
        pq/copy_session.cpp
        pq/copy_to_reversible_tuples_session.cpp
        pq/copy_tuples_session.cpp
)

ADD_LIBRARY( ${PROGRAM_NAME} SHARED ${SOURCES} )


IF ( UNIX AND NOT APPLE )
    SET( rt_library rt )
ENDIF ()

SET(BOOST_COMPONENTS)
LIST(APPEND BOOST_COMPONENTS thread date_time system filesystem program_options serialization unit_test_framework context locale iostreams)
SET( Boost_USE_STATIC_LIBS ON CACHE STRING "ON or OFF" )

FIND_PACKAGE(Boost 1.53 REQUIRED COMPONENTS ${BOOST_COMPONENTS})
FIND_PACKAGE(PostgreSQL REQUIRED)

TARGET_INCLUDE_DIRECTORIES(${PROGRAM_NAME} PRIVATE ${PostgreSQL_INCLUDE_DIRS} "." )

find_package( Gperftools QUIET )
IF ( GPERFTOOLS_FOUND )
    message( STATUS "Found gperftools; compiling cli_wallet with TCMalloc")
    list( APPEND PLATFORM_SPECIFIC_LIBS tcmalloc )
ENDIF ()


SET( GLOBAL_LIBRARIES
    ${Boost_LIBRARIES}
    ${PostgreSQL_LIBRARIES}
    ${CMAKE_DL_LIBS}
    ${PLATFORM_SPECIFIC_LIBS}
)

IF ( HIVE_STATIC_BUILD )
    APPEND( GLOBAL_LIBRARIES "-static-libstdc++ -static-libgcc -lreadline" )
ENDIF ()

TARGET_LINK_LIBRARIES( ${PROGRAM_NAME} PRIVATE ${GLOBAL_LIBRARIES} )