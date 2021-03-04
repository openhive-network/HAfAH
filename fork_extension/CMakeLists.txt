CMAKE_MINIMUM_REQUIRED( VERSION 3.2 )

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

SET(BOOST_COMPONENTS)
LIST(APPEND BOOST_COMPONENTS thread date_time system filesystem program_options serialization unit_test_framework context locale iostreams)
SET( Boost_USE_STATIC_LIBS ON CACHE STRING "ON or OFF" )

FIND_PACKAGE(Boost 1.53 REQUIRED COMPONENTS ${BOOST_COMPONENTS})
FIND_PACKAGE(PostgreSQL REQUIRED)

TARGET_INCLUDE_DIRECTORIES(${PROGRAM_NAME} PRIVATE ${PostgreSQL_INCLUDE_DIRS} "." )

SET( GLOBAL_LIBRARIES
    ${Boost_LIBRARIES}
    ${PostgreSQL_LIBRARIES}
    ${CMAKE_DL_LIBS}
    ${PLATFORM_SPECIFIC_LIBS}
)

TARGET_LINK_LIBRARIES( ${PROGRAM_NAME} PRIVATE ${GLOBAL_LIBRARIES} )