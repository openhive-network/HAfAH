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

# Starting plugin
1. To start plugin please execute as a postgres db client: `LOAD '$libdir/plugins/libfork_extension.so'` 
2. create trigger on observed table for example:
```
CREATE TRIGGER on_table_change AFTER DELETE ON table_name
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();
```
3. execute `back_from_fork` function: `SELECT back_from_fork();` to revert delete operations on observed tables

# Known problems
1. only delete operation on observed table is supported