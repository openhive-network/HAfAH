MACRO( ADD_PSQL_EXTENSION )
    CMAKE_PARSE_ARGUMENTS( EXTENSION "" "NAME" SOURCES ${ARGN} )

    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions )
    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME} )
    SET( extension_path  ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME} )
    SET( extension_control_file ${EXTENSION_NAME}.control )
    SET( extension_control_script ${EXTENSION_NAME}.sql )

    SET( GIT_REVISION "unknown" )

    FIND_PACKAGE(Git)
    IF ( GIT_FOUND )
        EXECUTE_PROCESS(
                COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE GIT_REVISION
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        MESSAGE( STATUS "GIT hash: ${GIT_REVISION}" )

        ADD_CUSTOM_COMMAND(
                OUTPUT  ${extension_path}/${extension_control_file}
                COMMAND sed 's/@GIT_REVISION@/${GIT_REVISION}/g' ${extension_control_file}  > ${extension_path}/${extension_control_file}
                COMMAND ${CMAKE_MODULE_PATH}/merge_sql.sh ${EXTENSION_SOURCES} > ${extension_path}/${EXTENSION_NAME}--${GIT_REVISION}.sql
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                DEPENDS ${EXTENSION_SOURCES} ${extension_control_file}
                COMMENT "Generate ${EXTENSION_NAME} to ${extension_path}"
        )

        ADD_CUSTOM_TARGET( extension.${EXTENSION_NAME} DEPENDS ${extension_path}/${extension_control_file} )

        INSTALL( DIRECTORY ${extension_path}/ DESTINATION ${POSTGRES_SHAREDIR}/extension OPTIONAL )
    else()
        MESSAGE( ERROR "GIT not found" )
    endif()
ENDMACRO()