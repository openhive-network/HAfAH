# HIVE_FORK
SQL Scripts which all together create an extension to support Hive Forks

## Installation
It is possible to install the extension in two forms - as a regular postgres extension
or as a simple set of tables and functions
### Install extension
1. create somwhere on a filesystem directory `build` and change terminal directory to it
2. `cmake <path to root of the project psql_tools>`
3. `make extension.hive_fork`
4. `make install`

The extension will be installed in the directory `<postgres_shareddir>/extension`. You can check the directory with `pg_config --sharedir`.

To start using extension in a database execute postgres command: `CREATE EXTENSION hive_fork`
### Execute sql scripts on Your database in given order:
The ordered list of sql scripts is included in the cmake file [src/hive_fork/CMakeLists.txt](./CMakeLists.txt).
Execute each script one by one with `psql` as in example: `psql -d my_db_name -a -f  context_rewind/data_schema.sql`
 
## Architecture
All elements of the extension are placed in 'hive' schema

The postgres extension is written in events source architecture style. It means that during live syncing
hived only schedules events, and then applications process them at their own pace.

It is possible to have multiple applications which process blocks independent on each other.

Blocks data are stored in two separated, but similar tables for irreversible and potentialy reversible blocks.

An Application groups its tables into named contexts (context are named only with alphanumerical characters + underscore).
Each context holds information about its processed events, blocks and a fork which is now processed. This pice of information
are enaugh to create views which presents combined irreversible and reversible blocks data.
Each of the views has name started from 'hive.{context_name}_{blocks|transactions|multi_signatures|operations}_view'  
### Overview of hive_fork and its relations with applications and hived
![alt text](./doc/evq_c3.png )

### Hived alghorithm
![alt text](./doc/evq_hived_process_blocks.png)


### Requirements for an application algorithm
![alt text](./doc/evq_app_process_block.png)

Any application must first create context, then creates its tables with inherit from hive.base. If application
wants to process some large number of irreversible blocks, then it must detach it contexts, do the sync, and attach the contexts again.
After massive processing of irreversible blocks an application has to call `hive.app_next_block` to get next block num to proces.
If NULL was returned an application must immediatly re-call `hive.app_next_block`. Any waiting (sleeps) for a new block are
executed by `hive.app_next_block`. When range of block number is returned then an application may edit its own tables and use blocks
data snaphot by asking 'hive.{context_name}_{ blocks | transactions | operations | transactions_multisig }' views. Views present
data snapshot for firt block in returned blocks range. If the range of returned blocks nums is large, then it may be worth to
back to massive sync - detach contexts, execute sync and attach the contexts - it will save triggers overhead during edition of the tables.

### Non-forking applications
It is expected that some applications won't use fork mechanism and will read only irreversible blocks. For such kind of applications
it is required to do not register any table in a context. Context without registered tables, lets name it 'irreversible context', will travers
only irreversible data of blocks - it means that function `hive.app_next_block` will return only range of irreversible, not already processed
blocks or NULL. Moreover set of views 'hive.{context_name}_{ blocks | transactions | operations | transactions_multisig }'
delivery only snapshot of irreversible data up to the block already processed by the application.

Summarizing, non-forking applications works in similar way as forking applications, but do not register tables within their contexts.

### Important notice about irreversible data
:warning: **Althought data of irreversible blocks are visible directly for the apllications, it is not recommented to use them.
It is expected that the structure of irreversible data will be changed in the future, but the stucture of context's views will stay not changed.
It means that the applications which read directly `irreversible blocks` may need to be refactored in the future to use newer version
of `hive_fork`.**

### REVERSIBLE AND IRREVERSIBLE BLOCKS
IRREVERSIBLE BLOCKS is information (set of database tables) about blocks which blockchain considern as irreveresible - they will never change.
You can check how th e tables look in the file [src/hive_fork/irreversible_blocks.sql](./irreversible_blocks.sql)

REVERSIBLE BLOCKS (set of database tables) is information about blocks for which blockachain is not sure if they are already irreversible, because they
may be a part of fork which will be abandoned soon. Please look at [src/hive_fork/reversible_blocks.sql](./reversible_blocks.sql)

Each application should work on a snapshot of blocks information, which is a combination of reversible and irreversible information based
on current status of the application's context - its last processed block and fork.

Because of the applications may work with different paces, the system has to hold reversible blocks information for every block num and fork not already processed by any
of the applications, this requires to construct an efficient data structure. Fortunetly the idea is quite simple - it is enaugh to add
to data inserted by hived block_num and fork id ( fork_id is a part of each reversible table ). The system controls forks ids - 
information about each fork is in hive.fork table. Moreover when 'hived' pushes a new block with function `hive.push_block`, then the system
adds information about current fork to a new reversible data. Reversible data tables can be presented in generalised form as in the example below:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    1    |  DATA_21  |
|    3     |    1    |  DATA_31  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |
|    4     |    2    |  DATA_42  |
|    4     |    3    |  DATA_43  |

If application is working on fork=2 and block_num=3 ( this information is held by `hive.context` ) then its snapshot of data for example above is:

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
JOIN hive.context hc ON fork_id <= hc.fork_id AND block_num <= hc.current_block_num
WHERE hc.name = 'app_context'
ORDER BY block_num DESC, fork_id DESC
```
Remark: The fork_id is not a part of blockchain, it is only a helpful part of hive_fork extension and may differ with any instation of the extension.

### EVENTS QUEUE
Events queue is a table defined in [src/hive_fork/events_queue.sql](./events_queue.sql). Each row in the table represents an event.
Each event is defined with its **id**, **type** and BIGINT **block_num** value. The `block_num` value has different meaning for a different
type of events:

|   event type     | block_num meaning                                     |
|----------------- |-----------------------------------------------------  |
| BACK_FROM_FORK   | fork id of corresponding entry in `hive.fork`         |
| NEW_BLOCK        | num of the new block                                  |
| NEW_IRREVERSIBLE | num of irreversible block                             |
| MASSIVE_SYNC     | the higest num of blocks pushed massivly by the hived |

Events are ordered by the **id**, thus event that happen earlier has lower id than next events. The events queue
is traversed by the application when they call `hive.app_next_block` - the lowest event form all with id higer than
`event_id` form context is choosen and processed, and at the end context's 'event_id' is updated.

#### Optimizaton of forks
There are situations when application don't have to travers events queue and process all the events. When there are
`BACK_FROM_FORK` events ahead of a context's `event_id`, then we can ommit all events before the fork with lower `block_num`, what can be presented as here:
![](./doc/evq_events_optimization.png)

The optimization above is implemented in [src/hive_fork/app_api_impl.sql](./app_api_impl.sql) in function `hive.squash_events`
and is calle by `hive.app_next_block` function.

#### Removing obsolete events
Because the applications never back to already processed events, during time some events become useless and redundant.
Events in which releates to blocks which already become irreversible and were already processed by the all of contexts
are removed by the hived with function `hive.set_irreversible`.


### CONTEXT REWIND
The part of the extension which is responsible to register App tables, save and rewind  operation on the tables.

An application and hived shall not use directly any function from directory [src/hive_fork/context_rewind](./context_rewind/).

An application must register those its tables, which are dependant on hive blocks.
Any table is automaticly registerd during its creation only when inherits from hive.base. 
. A table is registered into recently created context. If there is no context an exception is thrown.

```
CREATE TABLE table1( id INTEGER ) INHERITS( hive.base )
```
hive.base table is defined here: [context_rewind/data_schema.sql](./context_rewind/data_schema.sql).

Data from 'hive.base' is used by the fork system to rewind operations. Especially column 'hive_rowid'
is used by the system to distinguish between edited rows. During registartion a set of triggers are
enabled on a table, they will record any changes.
Moreover a new table is created - a shadow table which structure is the copy of a registered table + columns for operation
registered tables. A shadow table is the place where triggers records changes. A shadow table is created in 'hive' schema
and its name is created with the rule below:
```
hive.shadow_<table_schema>_<table_name>
```
It is possible to rewind all operations registered in shadow tables with `hive.context_back_from_fork`

Because triggers itself add some significant overhead for operations, in some situation it may be necessary
to temporary disable them for sake of better performance. To do this there are functions: `hive.detach_table` - to disable
triggers and 'hive.attach_table' to enable triggers. When triggers are disabled no support for hive fork is enabled for a table,
so the application should solve the situation (in most cases is should happen when blocks below irreversible are processed, so no forks happen there)

It is quite possible that the application which use the fork system will want to change the structure of the registered tables.
It is possible only when coresponding shadow tables are empty. It means before an upgrade application must be in state
in which there is no pending fork. The system will block ( rise an excpetion ) 'ALTER TABLE' command if corresponding shadow table is not empty.
When a table is edited its shadow table is automaticly adapted to a new structure ( in fact old shaped shadow table is dropped and a new one is created with a new structure )

## Database structure
### HIVE FORK
![alt text](./doc/evq_fork_db.png)

#### Reversible blocks
Tables for reversible blocks are copies of irreveersible + columns for fork_id
##### hive.blocks_reversible
##### hive.transactions_reversible
##### hive.transactions_multisig_reversible
##### hive.operations_reversible

### CONTEXT REWIND
![alt text](./doc/evq_context_rewind_db.png)

## SQL API
The set of scripts implements an API for the applications:
### Public - for the user
#### HIVED API
The functions which are used by hived
##### hive.back_from_fork( _block_num_before_fork )
Schedules back from fork

##### hive.push_block( _block, transactions[], signatures[], operations[] )
Push new block with its transactions, their operations and signatures

##### hive.set_irreversible( _block_num )
Set new irreversible block

#### hive.end_massive_sync()
After fnishing massive push of blocks hived will invoke this metod to schedlue MASSIVE_SYNC event. The parameter `_block_num`
is a last massivly synced block - head or irreversible blocks.

#### APP API
The functions which should be used by an application

##### hive.app_create_context( _name )
Creates a new context. Context name can contains only characters from set: `a-zA-Z0-9_`

##### hive.app_next_block( _context_name )
Returns `hive.blocks_range` -range of blocks numbers to process or NULL
It is a most important function for any application.
To ensure correct work of fork rewind mechanism any application must process returned blocks and modify their tables according
to block chain state on time where the returned block is a head block.

If NULL is returned, then there is no block to process or events which did not delivery blocks were processed. 

Returns range of blocks to process, if range is empty ( first and last blocks are the same ), then an application
must process the one returned block num, if range is grater than 0, (last_block -first_block) > 0, it means that hived
executed massive sync - a large number of irreversible blocks are added, and an application can process them massively without
fork control (detach context is required), or still process them one by one ( process the first_block in range and then back to `hive.app_next_block` to get
next block, but it will  be slower because of triggers overhead ).

hive.app_next_block cannot be used when context is detached - in such case an exception is thrown.

##### hive.app_context_detach( context_name )
Detaches triggers atatched to register tables in a given context, It allow to do a massive sync of irreversible
blocks without triggers overhead.

##### hive.app_context_attach( context_name, block_num )
Enables triggers attached to registered tables in a given context and set current context block num. The `block_num` cannot
be greater than top of irreversible block.

#### CONTEXT REWIND
Context rewind function shall not be used by hived and applications.

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

#### hive.registered_table
Registers an user table in the fork system, is used by the trigger for CREATE TABLE

#### hive.create_shadow_table
Creates shadow table for given table

#### hive.attach_table( schema, table )
Enables triggers atatched to a register table.

#### hive.detach_table( schema, table )
Disables triggers atatched to a register table. It is usefull for operation below irreversible block
when fork is impossible, then we don't want have trigger overhead for each edition of a table.

## Known Problems
1. Constraints like FK, UNIQUE, EXCLUDE, PK must be DEFERRABLE, otherwise we cannot guarnteen success or rewinding changes.
   More informations about DEFERRABLE constraint can be found in PosgreSQL documentaion for [CREATE TABLE](https://www.postgresql.org/docs/10/sql-createtable.html)
   and [SET CONSTRAINTS](https://www.postgresql.org/docs/10/sql-set-constraints.html)

## Other architectures which were abandoned
### C++ extension
There was a hope that extension written in C/C++ can be more performance and access to a low level of PostgreSQL can give some benefits.
The most important problem in the project is to rewind reversible changes in a way which do not violate
the constraints of tables. It was implemented by encoding changed blobs of rows from the registered tables into byte arrays and save them
in a separated table in the order in which the changes occur ( actually the stack of changed rows was implemented ). The extension was
implemented and then abandoned with the [commit](https://gitlab.syncad.com/hive/psql_tools/-/commit/e6ac13be5d137fe0de5d7fe916905a9b97a11bdc).
There were few reasons to resign from C/C++ extension:
1. The extension could cause crash not only the client connection but also the main PostgreSQL server process ( what was observed )
2. The documentation for PostgreSQL C interface is terse, and for some details PostgresSQL source code needed to be analyzed.
3. There was a doubt about portability of such extension between different version of PostgreSQL, indeed the extension was working
   with PostgreSQL 10, but did not work with PostgreSQL 13.
4. It turned out that it was impossible to execute some actions only with C iterface and execute SQL queries from the code was required.
5. It turned out that the C/C++ extension was slower than current SQL implementation in every test. The report is [here](https://gitlab.syncad.com/hive/psql_tools/-/blob/c1140df5f72a29df4d3d26d95f63e52595702c3c/doc/Performance.md)
6. Code in C/C++ is more complicated than SQL. The implementation of rewinding reversible operation in C++ took more than 3 weeks, and implementation of similar functionality
   with SQl took a week.
   
### SQL extension with one stack of changes ( no shadow tables )
It turned out that it is impossible to implement with SQL similar stack of changed rows as was implemented in C++ extension.
There is no method to take and save blob of a table's row in a generic form, so it is not possible to have a common table for all changes
from different tables.


### SQL extension without events queue
When the SQL method of rewinding reversible tables was implemented ( this part is now named `context_rewind` ), there was a noble
idea to use it for rewinding both the applications tables and the tables filled directly by hived. Relatively simple implementation
of the whole extension was possible - hived will have its tables registered in its context and in case of back from a fork, the tables are reminded.
Unfortunately, during analysis, it was found that this kind of architecture will require to use of locks on hived's tables to solve
race condition between the reading hived tables by the applications and modifying them by hived. Introducing locking will
make hived work dependant on applications quality - how fast they will commit transactions to release locks. Moreover, the applications
become dependant on each other, because one application may block hived and other applications could not get new live blocks.