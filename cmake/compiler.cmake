MACRO( SETUP_OUTPUT_DIRECTORIES )
    SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    SET(GENERATED_FILES_DIRECTORY_ROOT ${CMAKE_BINARY_DIR}/generated/)
    SET(GENERATED_FILES_DIRECTORY ${CMAKE_BINARY_DIR}/generated/gen)
    FILE( MAKE_DIRECTORY ${GENERATED_FILES_DIRECTORY} )
ENDMACRO()

MACRO( SETUP_COMPILER target_name )
    TARGET_COMPILE_OPTIONS( ${target_name}  PRIVATE -Wall )
    TARGET_INCLUDE_DIRECTORIES( ${target_name}
            PRIVATE
            ${PROJECT_SOURCE_DIR}/common_includes
            "."
            ${GENERATED_FILES_DIRECTORY_ROOT}
            # form hive project
            ${HAF_DIRECTORY}/hive/libraries/fc/include
            ${HAF_DIRECTORY}/hive/libraries/appbase/include
            ${HAF_DIRECTORY}/hive/libraries/utilities/include
    )
ENDMACRO()