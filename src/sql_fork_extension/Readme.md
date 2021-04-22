# SQL FORK EXTENSION
SQL Scripts which all together creates an extension to support Hive Forks

## Architecture
All elements of the extension are placed in 'hive' schema

An application must register its tables dependent on hive blocks.
Any table is automaticly registerd during its creation only when inherits form hive.base. 
. A table is resgistered into recently created context If there is no context an exception is thrown.

```
CREATE TABLE table1( id INTEGER ) INHERITS( hive.base )
```

Data from 'hive.base' is used by the fork system to rewind operations. Especcially column 'hive_rowid'
is used by the system to distinguish between edited rows. During registartion a set of triggers are
enabled on a table, they will record any changes.
Moreover a new table is created - a shadow table which structure is the copy of a registered tables + columns for operation
registered tables. A shadow table is the place where triggers records changes. A shadow table is created in 'hive' schema
an is name is created with the rule below:
```
hive.shadow_<table_schema>_<table_name>
```
It is possible to rewind all operation registered in shadow tables with `hive_back_from_fork`
type and block num. Further triggers are created, which will fill the shadow tables with any edition of


Because triggers itself add some significant overhead for operations, in some situation it may be necessary
to temporary disable them for sake of better performance. To do this  there are functions: `hive.detach_table` - to disable
triggers and 'hive.attach_table' to enable triggers. WHen triggers are disabled no support for hive fork is enabled for a table,
so the application should solve the situation (in most cases is should happen when blocks below irreversible are processed, so no forks happen there)
## Installation
Execute sql scripts on Your database in given order:
1. data_schema.sql
1. event_triggers.sql
1. context.sql
1. register_table.sql 
1. detach_table.sql
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
6. is_attached - True if triggers are enabled ( a table is attached ), False when are disbaled ( a table is detached )

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
### Public - for the user
#### hive.detach_table( schema, table )
Disables triggers atatched to a register table. It is usefull for operation below irreversible block
when fork is impossible, then we don't want have trigger overhead for each edition of a table.

#### hive.detach_all( context_name )
Detaches triggers atatched to register tables in a given context

#### hive.attach_table( schema, table )
Enables triggers atatched to a register table.

#### hive.attach_all( context_name )
Enables triggers atatched to register tables in a given context 

#### hive.create_context( context_name )
Creates the context - controll block number on which the registered tables are working

#### hive.context_next_block( context_name )
Moves a context to the next available block

#### hive.back_from_fork()
Rewind register tables, empty the sahdow tables

### Private - shall not be called by the user
#### hive.registered_table
Registers an user table in the fork system, is used by the trigger for CREATE TABLE

## TODO
1. Validation of the registered tables
3. Validation of structure

## Known Problems
1. Constraints like FK, UNIQUE, EXCLUDE, PK must be DEFFERABLE, otherwise we cannot guarnteen success or rewinding changes
2. Because all registered tables inherit from hive.base they share a coomon hive_rowid SERIAL, so there is a 64bits limit for all rows in all register tables.

