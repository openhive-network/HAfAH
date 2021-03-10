MACRO( ADD_BOOST_LIBRARIES target_name )
    SET( BOOST_COMPONENTS )
    LIST( APPEND BOOST_COMPONENTS
            thread
            date_time
            system
            filesystem
            program_options
            serialization
            unit_test_framework
            context locale iostreams
    )
    SET( Boost_USE_STATIC_LIBS ON CACHE STRING "ON or OFF" )

    FIND_PACKAGE( Boost 1.53 REQUIRED COMPONENTS ${BOOST_COMPONENTS} )

    TARGET_LINK_LIBRARIES( ${target_name} PRIVATE ${Boost_LIBRARIES} )
ENDMACRO()

MACRO( ADD_POSTGRES_LIBRARIES target_name )
    FIND_PACKAGE( PostgreSQL REQUIRED )

    TARGET_LINK_LIBRARIES( ${target_name} PRIVATE ${PostgreSQL_LIBRARIES} )
ENDMACRO()

MACRO( ADD_POSTGRES_INCLUDES target_name )
    FIND_PACKAGE( PostgreSQL REQUIRED )

    TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${PostgreSQL_INCLUDE_DIRS} )
ENDMACRO()