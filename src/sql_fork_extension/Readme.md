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
1. event_triggers.sql
1. context.sql
1. register_table.sql 
1. unregister_table.sql
1. back_from_fork.sql

An example of script execution: `psql -d my_db_name -a -f  data_schema.sql`

## Database structure
The script `data_schema.sql` creates all necessary tables in `hive` schema.

### hive.context
Used to control currently processed blocks for application's tables registered together in th eone context. 

Columns
1. id - id of the context
2. name - human redable name of the context, thathts for better readability of the application code
3. current_block_num - current hive block num processed by the tables registered in the context

### hive.registered_tables
Contains information about registered application tables and their contexts

Columns
1. id - id of the registered table
2. context_id - id of the context in which the table is registered
3. origin_table_name - name of the registered table
4. shadow_table_name - name of the shadow table name for a registered table
5. origin_table_columns - names of origin table's columns

### hive.triggers_operations
Names of operation on origin tables which we can revert

Columns
1. id - id of the operation
2. name - name of operation

### hive.triggers
Contains informations about triggers created by the extension

Columns
1. id - id of the trigger
2. registered_table_id - id ot the rgeistered table which triggers the trigger
3. trigger_name - trigger name
4. function_name - function name called by the trigger

### hive.control_status
Global information required by the extension functions and trigger

Columns
1. id - technical trick to do not allow to have more than one row
2. back_from_fork - flag which indicated that back_from_fork is in progress

## SQL API
The set of scripts implements an API for the applications:
### hive_registered_table
Registers an user table in the fork system
### hive_unregistered_table
Unregisters an user table from the fork system
### hive_create_context
Creates the context - controll block number on which the registered tables are working
### hive_context_next_block
Moves a context to the next available block
### hive_back_from_fork
Rewind register tables

## TODO
2. unregister table with DROP table
2. move function to hive schema
1. Validation of the registered tables
2. Tables unregistration ( may be need by the user to service action on the tables without triggering hive fork mechanism)
3. Validation of structure

## Known Problems
1. Constraints like FK, UNIQUE, EXCLUDE, PK must be DEFFERABLE, otherwise we cannot guarnteen success or rewinding changes

