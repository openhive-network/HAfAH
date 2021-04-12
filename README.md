# psql_tools

Contains implementations of Postgres specific tools providing functionalities required by other projects storing blockchain data in the Postrges database.

# Compilation
## Requirements
1. Ubuntu 18.04
2. postgresql server dev package: `sudo apt-get install postgresql-dev`

## CMake and make
1. update submodules: 'git submodule update --init --recursive'
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake ..`
4. `make`

# Tests
The project use ctest to start tests, just execute in build directory `make test`

Test are grouped in a three by names and `.` as a branch separator where 'test' is the root.
For example You can start all unit tests with command `ctest -r test.unit.*` 

# Installation
Postgres plugins has to be copied into postgres `$libdir/plugins directory`

You can check postgres `$libdir` directory with: `pg_config --pkglibdir`

The best option is to execute `make install` from build directory

# Architecture
## Directory structure
   ```
   cmake                      Contains common function used by cmake build
   common_includes
        include               Constains library interfaces header files, to share them among the project items
   doc                        Contains documentation documents
   src                        Contains sources
        fork_extension        Contains C language extension which implements solution for hive forks
        pq_utils              C++ interface for PostgreSQL PQ interface
        psql_utils            C++ utilities to PostgreSQL C interfaces
        sql_fork_extension    Contains SQL extension which implements solution for hive forks 
   tests                  Contains test
        functional        Contains functional tests
        unit              Contains unit tests and mocks
            mockups       Contains mocks 
   ```

There is also a `generated` directory inside the build directory. It contains autmatically generated headers which can be included
in the code whith ```#include "gen/header_file_name.hpp"```
## Error handling
- Exceptions are used as an error handling method
- Each PostgreSQL 'C' entry points have to catch all unhandled exceptions and logs them as errors using LOG_ERROR macro
  what breaks pending transaction
- RAII is in use - each our object contructors may throw PsqlTools::ObjectInitializationException

## C++ coding standard
1. use C++14
2. class names start with upper case and use CamelCase __ClassName__
3. method names start with lower case and use CamelCase __camelCase__
4. all instations (objects, variables, attributes, class membert) use snake_case
5. functions attribute start with underscore ___function_attribute_name__
6. class members starts with 'm_' __m_class_member_name__
7. global and static variable are written in upper case without prefixes __GLOBAL_VARIABLE_NAME__
8. templete attributes use CamelCase started with underscore and lower case  _templeteAttribute
9. file and directory names with snake_case: my_file.cpp

# Known problems
