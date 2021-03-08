#pragma once

#include "include/postgres_includes.hpp"

#define STRINGIZE(x) STRINGIZE2(x)
#define STRINGIZE2(x) #x

#define LOG_TO_POSTGRES( _level, _file, _line, _message, ... )                        \
  elog( _level, _file ":" _line ": " _message, ##__VA_ARGS__ )                        \

#define LOG_WARNING( _message, ... )                                                  \
  LOG_TO_POSTGRES( WARNING, __FILE__, STRINGIZE(__LINE__), _message, ##__VA_ARGS__ )  \

#define LOG_INFO( _message, ... )                                                     \
  LOG_TO_POSTGRES( INFO, __FILE__, STRINGIZE(__LINE__), _message, ##__VA_ARGS__ )     \


#define LOG_ERROR( _message, ... )                                                    \
  LOG_TO_POSTGRES( ERROR, __FILE__, STRINGIZE(__LINE__), _message, ##__VA_ARGS__ )    \

