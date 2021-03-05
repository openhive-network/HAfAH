#pragma once

#define DO_PRAGMA_(_x) _Pragma (#_x)

#define DEFINE_PSQL_FUNCTION( _function_name )            \
DO_PRAGMA_( GCC diagnostic push )                         \
                                                          \
DO_PRAGMA_( GCC diagnostic ignored "-Wunused-parameter" ) \
                                                          \
Datum back_from_fork(PG_FUNCTION_ARGS) try {              \
                                                          \
DO_PRAGMA_( GCC diagnostic pop )                          \




