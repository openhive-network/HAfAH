# Functional test
The tests start sql scripts which checks fork_extension plugin functionalities.

# Tests coventions
- #### Each test case is a separated sql script
- #### Tests are always started on empty database
- #### Each tests contains three sql function:
1. __test_given__ setup state before execution functionality uder test
2. __test_when__ executes functionality under test
3. __test_then__ validate results of executed functionality
- #### Each test file name starts with a name of tested functionallity

# Requirements
- The tests require to have configured locally (means on local host) postgres server with the current system user as postgres SUPERUSER with CREATEDB option
and authentication method peer(setting inside `pg_hba.conf`)
- The 'fork_extension' plugin must be installed, the best option is to execute first `make install` from a build directory