# SQL FORK EXTENSION
SQL Scripts which all together creates an extension to support Hive Forks

## Architecture
An application must register its tables dependent on hive blocks. During a table registration it is extendend
for a new column `hive_rowid` which is required by the system to distinguish between edited rows. Next
a new table is created - a shadow table which structure is the copy of a registered tables + columns for operation
type and block num. Further triggers are created, which will fill the shadow tables with any edition of
registered tables. It is possible to rewind all operation registered in shadow tables with `hive_back_from_fork`

## Installation
Execute sql scripts on Your database in given order:
1. data_schema.sql
1. context.sql
1. register_table.sql
1. back_from_fork.sql

An example of script execution: `psql -d my_db_name -a -f  data_schema.sql`

## SQL API
The set of scripts implements an API for the applications:
### hive_registered_table
Registers an user table in the fork system
### hive_create_context
Creates the context - controll block number on which the registered tables are working
### hive_context_next_block
Moves a context to the next available block
### hive_back_from_fork
Rewind register tables

## TODO
1. schemas support
1. Validation of the registered tables
2. Tables unregistration ( may be need by the user to service action on the tables without triggering hive fork mechanism)
3. Validation of structure

## Known Problems
1. Constraints like FK, UNIQUE, EXCLUDE, PK must be DEFFERABLE, otherwise we cannot guarnteen success or rewinding changes

