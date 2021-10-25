SET( target_name "transaction_controllers")

ADD_STATIC_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE  ${PROJECT_SOURCE_DIR}/hive/libraries/fc/include )