# psql_tools

Contains implementations of Postgres specific tools providing functionalities required by other projects storing blockchain data in the Postrges database.

# Compilation
## Requirements
1. Tested on Ubuntu 20.04
2. postgresql server dev package: `sudo apt-get install postgresql-dev-12`
3. ssl dev package:               `sudo apt-get install libssl-dev`
4. readline dev package:          `sudo apt-get install libreadline-dev`


## CMake and make
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake ..`
4. `make`

### Choose version of the Postgres to compile with
CMake variable `POSTGRES_INSTALLATION_DIR` is used to point the installation folder
with PostgreSQL binaries, by default it is `/usr/lib/postgresql/12/bin` - place where Postgres v.12
is installed on Ubuntu. An example of choosing different version of Postgres:
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake -DPOSTGRES_INSTALLATION_DIR=/usr/lib/postgresql/10/bin ..`
4. `make`

# Tests
The project uses ctest to start tests, just execute in build directory `make test`

Test are grouped in a tree by names and `.` as a branch separator where 'test' is the root.
For example You can start all unit tests with command `ctest -R test.unit.*` 

# Installation
Postgres plugins has to be copied into postgres `$libdir/plugins directory`

You can check postgres `$libdir` directory with: `pg_config --pkglibdir`

The best option is to execute `make install` from build directory

# Architecture
## Directory structure
   ```
   cmake                      Contains common functions used by cmake build
   common_includes
        include               Constains library interfaces header files, to share them among the project items
   doc                        Contains documentation
   src                        Contains sources
        pq_utils              C++ interface for PostgreSQL PQ interface
        psql_utils            C++ utilities to PostgreSQL C interfaces
        hive_fork_manager     Contains SQL extension which implements solution for hive forks 
   tests                      Contains test
        integration           Folder for non-unit tests like functional or system tests
          functional          Contains functional tests
        unit                  Contains unit tests and mocks
            mockups           Contains mocks 
   ```

There is also a `generated` directory inside the build directory. It contains autmatically generated headers which can be included
in the code whith ```#include "gen/header_file_name.hpp"```
## Error handling in C++
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

## PSQL extension based on sql script
If there is a need to create psql extension ( to use CREATE EXTENSION psql command ) a cmake macro is added:
`ADD_PSQL_EXTENSION` with parameters:
- NAME - name of extension, in current source directory file <name>.control (see https://www.postgresql.org/docs/10/extend-extensions.html#id-1.8.3.18.11 ) 
- SOURCES - list of sql scripts, the order of the files is important since they are compiled into one sql script

The macro creates a new target extension.<name_of_extension>. The command 'make extension.<name_of_extension>' will create
an psql extension in `${CMAKE_BINARY_DIR}/extensions/<name>`.
To install the extension please execute 'make install'.

Warning: Make install will install all already builded project items, to install only one of them please build it
in separated build directory with making the only one target, for example: `make extension.hive_fork_manager; make install;` 

### Versioning
Postgres extensions are versioned - extension control file contains `default_version` configuration entry. The build system
fills the entry with the repository git sha converted to decimal presentation (postgres accepts only digits in version string).
Also corresponding sql script file is named with the same version, as is required by the postgres.
# Known problems
