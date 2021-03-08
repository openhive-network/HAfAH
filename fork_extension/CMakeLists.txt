CMAKE_MINIMUM_REQUIRED( VERSION 3.2 )

SET( target_name fork_extension )

SET( sources
        initialization.cpp
        endpoints/trigger.cpp
        endpoints/back_from_fork.cpp
        initializer.cpp
        pq/db_client.cpp
        pq/copy_session.cpp
        pq/copy_to_reversible_tuples_session.cpp
        pq/copy_tuples_session.cpp
        )

ADD_RUNTIME_LOADED_LIB( ${target_name} "${sources}" )