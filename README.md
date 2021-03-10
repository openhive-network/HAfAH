# psql_tools

Contains implementations of Postgres specific tools providing functionalities required by other projects storing blockchain data in the Postrges database.

# Compilation
## Requirements
1. Ubuntu 18.04
2. postgresql server dev package: `sudo apt-get install postgresql-dev`

## CMake and make
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake ..`
4. `make`

# Tests
The project use ctest to start tests, just execute in build directory `make test`

Test are grouped in three by names and `.` as branch separator where 'test' is the root. For example You can start
all unit test with command `ctest -r test.unit.*` 

# Installation
Postgres plugins has to be copied into postgres `$libdir/plugins directory`

You can check postgres `$libdir` directory with: `pg_config --pkglibdir`

The best option is to execute `make install` from build directory

# Starting plugin
To start plugin please execute as a postgres db client: `LOAD '$libdir/plugins/libfork_extension.so'` 
