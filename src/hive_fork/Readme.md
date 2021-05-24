# HIVE_FORK
SQL Scripts which all together create an extension to support Hive Forks

## Architecture
All elements of the extension are placed in 'hive' schema

The postgres extension is written in events source architecture style. It means that during live syncing
hived only schedules events, and then application procces them at his own pace.

It is possible to have multiple applications which process blocks independent on each other.

Blocks data are stored in two separated, but similar tables for irreversible and potentialy reversible blocks.

An Application groups its tables into named contexts (context are named only with alphanumerical characters). Each contexts holds information about its processed events and
a fork which is now processed. These two pice of information are enaugh to create views which presents combined irreversible and
reversible blocks data. Each of the views has name started from 'hive.{context_name}_'  

### REVERSIBLE AND IRREVERSIBLE BLOCKS
IRREVERSIBLE BLOCKS is information (set of datbase tables) about blocks which blockchain considern as irreveresible - it will never change.

REVERSIBLE BLOCKS (set of datbase tables) is information about blocks for which blockachain is not sure if they are already irreversible, because they
may be a part of fork which will be abandoned soon.

Each application should works on snapshot of blocks information, which is a combination of reversible and irreversible information based
on current status of the application - its last processed block and fork.

Because applications may work with different paces, the system has to hold reversible blocks information for every block num and fork not already processed by any
of the applications, this requires to construct an efficient data structure. Fortunetly the idea is quite simple - it is enaugh to add
to data inserted by hived block_num and fork id ( fork_id is a part of each reversible table ). The system controls forks ids - set
information about each fork in hive.fork table. Moreover when 'hived' pushes a new block with function `hive.push_block`, then the system
adds information about current fork to a new irreversible data. Irreversible data tables can be presented in generalised form as in the example below:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    1    |  DATA_21  |
|    3     |    1    |  DATA_31  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |
|    4     |    2    |  DATA_42  |
|    4     |    3    |  DATA_43  |

If application is working on fork=2 and block_num=3 ( this information is held by `hive.app_context` ) then its snapshot of data for example above is:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |

It means snaphot of data for an application with context `app_context` can be obtained by filtrating blocks and forks with relativly simple SQL query like:
```
SELECT
      DISTINCT ON (block_num) block_num
    , fork_id
    , data
FROM data_reversible
JOIN hive.app_context hc ON fork_id <= hc.fork_id AND block_num <= hc.current_block_num
WHERE hc.name = 'app_context'
ORDER BY block_num DESC, fork_id DESC
```

### CONTEXT REWIND
The part of the extension which is responsible to register App tables, save and rewind  operation on the tables.

An application must register its tables depend of hive blocks.
Any table is automaticly registerd during its creation only when inherits form hive.base. 
. A table is resgistered into recently created context.If there is no context an exception is thrown.

```
CREATE TABLE table1( id INTEGER ) INHERITS( hive.base )
```

Data from 'hive.base' is used by the fork system to rewind operations. Especially column 'hive_rowid'
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

It is quite possible that the application which use the fork system will want to change the structure of the registered tables.
It is possible only when coressponding shadow tables is empty. It means before an upgrade application must be in state
in which there is no pending fork. The system will block ( rise an excpetion ) 'ALTER TABLE' command if corresponding shadow table is not empty.
When a table is edited its shadow table is automaticly adapted to a new structure ( in fact old shaped shadow table is dropped and a new one is created with a new structure )

## Installation
Execute sql scripts on Your database in given order:
1. context_rewind/data_schema.sql
1. context_rewind/event_triggers.sql
1. context_rewind/register_table.sql
1. context_rewind/detach_table.sql
1. context_rewind/back_from_fork.sql
1. context_rewind/irreversible.sql
1. context_rewind/rewind_api.sql
1. data_schema.sql
1. hived_api.sql

An example of script execution: `psql -d my_db_name -a -f  data_schema.sql`

## Database structure
The scripts `data_schema.sql` files create all necessary tables in `hive` schema.

### HIVE FORK

#### hive.forks
hive.fork

Columns
1. id - id of the fork
2. block_num last block before the fork
3. time_of_fork time of signaling fork by hived

#### hive.events_queue

Columns 
1. id - id of the event
2. event - type of the event
3. block_num - block num that releates to the event

##### hive.app_context
Inherits from hive.context

1. event_id - id of the last processed event

### Additionaly to tables above hive_fork contains tables for irreversible and reversible blocks data

#### Irreversible blocks

##### hive.blocks
##### hive.transactions
##### hive.transactions_multisig
##### hive.operation_types
##### hive.operations

#### Reversible blocks
Tables for rreversible blocks are copies of irreveersible + columns for fork_id
##### hive.blocks_reversible
##### hive.transactions_reversible
##### hive.transactions_multisig_reversible
##### hive.operations_reversible

### CONTEXT REWIND
#### hive.context
Used to control currently processed blocks for application's tables registered together in the one context. 

Columns
1. id - id of the context
2. name - human redable name of the context, thathts for better readability of the application code
3. current_block_num - current hive block num processed by the tables registered in the context
4. irreversible_block - irreversible block num, the higest block known by the context which cannot be reedited during back from fork
4. is_attached - True if triggers are enabled ( a table is attached ), False when are disbaled ( a table is detached )

#### hive.registered_tables
Contains information about registered application tables and their contexts

Columns
1. id - id of the registered table
2. context_id - id of the context in which the table is registered
3. origin_table_name - name of the registered table
4. shadow_table_name - name of the shadow table name for a registered table
5. origin_table_columns - names of origin table's columns

#### hive.triggers
Contains informations about triggers created by the extension

Columns
1. id - id of the trigger
2. registered_table_id - id ot the rgeistered table which triggers the trigger
3. trigger_name - trigger name
4. function_name - function name called by the trigger

#### hive.control_status
Global information required by the extension functions and trigger
1. back_from_fork - integral flag, which tell tell the system if back_from_fork is in progress
2. irreversible_block - irreversible block num, the higest block which cannot be reedited during back from fork

Columns
1. id - technical trick to do not allow to have more than one row
2. back_from_fork - flag which indicated that back_from_fork is in progress

## SQL API
The set of scripts implements an API for the applications:
### Public - for the user
#### HIVED API
##### hive.back_from_fork( _block_num_before_fork )
Schedules back from fork

##### hive.push_block( _block, transactions[], signatures[], operations[] )
Push new block with its transactions, their operations and signatures

##### hive.set_irreversible( _block_num )
Set new irreversible block

#### CONTEXT REWIND
##### hive.context_detach( context_name )
Detaches triggers atatched to register tables in a given context

##### hive.context_attach( context_name, block_num )
Enables triggers attached to register tables in a given context and set current context block num 

##### hive.context_create( context_name )
Creates the context with controll block number on which the registered tables are working

##### hive.context_next_block( context_name )
Moves a context to the next available block

##### hive.context_back_from_fork( context_name, block_num )
Rewind only tables registered in given context to given block_num

### Private - shall not be called by the user
#### hive.registered_table
Registers an user table in the fork system, is used by the trigger for CREATE TABLE

#### hive.create_shadow_table
Creates shadow table for given table

#### hive.attach_table( schema, table )
Enables triggers atatched to a register table.

#### hive.detach_table( schema, table )
Disables triggers atatched to a register table. It is usefull for operation below irreversible block
when fork is impossible, then we don't want have trigger overhead for each edition of a table.

## TODO
1. Validation of the registered tables
3. Validation of structure

## Known Problems
1. Constraints like FK, UNIQUE, EXCLUDE, PK must be DEFFERABLE, otherwise we cannot guarnteen success or rewinding changes

