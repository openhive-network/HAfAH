# Functional test
The tests start sql scripts which checks fork_extension plugin functionalities.
# Requirements
The tests require to have configured locally (means on local host) configured postgres server with the current system user as postgres SUPERUSER with CREATEDB option
and authentication method peer(setting inside `pg_hba.conf`)