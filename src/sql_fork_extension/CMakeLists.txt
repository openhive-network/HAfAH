MACRO( ADD_PSQL_EXTENSION name )
    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions )
    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions/${name} )
    SET( extension_path  ${CMAKE_BINARY_DIR}/extensions/${name} )
    SET( extension_control_file ${name}.control )
    SET( extension_control_script ${name}.sql )

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

        # COMMAND sh -c "sed 's/@GIT_REVISION@/${GIT_REVISION}/g' ${extension_control_file}  > ${extension_path}/${extension_control_file}"
        ADD_CUSTOM_COMMAND(
                OUTPUT  ${extension_path}/${extension_control_file}
                COMMAND sed 's/@GIT_REVISION@/${GIT_REVISION}/g' ${extension_control_file}  > ${extension_path}/${extension_control_file}
                COMMAND ./merge_sql.sh > ${extension_path}/${name}--${GIT_REVISION}.sql
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMENT "Generate ${name} to ${extension_path}"
        )

        ADD_CUSTOM_TARGET( extension.${name} DEPENDS ${extension_path}/${extension_control_file} )

        INSTALL( DIRECTORY ${extension_path}/ DESTINATION ${POSTGRES_SHAREDIR}/extension OPTIONAL )
    else()
        MESSAGE( ERROR "GIT not found" )
    endif()

    CONFIGURE_FILE( ${CMAKE_MODULE_PATH}/git_version.hpp.in ${GENERATED_FILES_DIRECTORY}/git_version.hpp @ONLY )
ENDMACRO()

ADD_PSQL_EXTENSION( hive_fork )