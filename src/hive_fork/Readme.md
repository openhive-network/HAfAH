# HIVE_FORK_MANAGER
The fork manager is composed of SQL scripts to create a Postgres extension that provides an API that simplifies reverting application data when a fork switch occurs on the Hive blockchain.

## Installation
It is possible to install the fork manager in two forms - as a regular Postgres extension or as a simple set of tables and functions.

### Install fork manager as an extension
1. create somwhere on a filesystem directory `build` and change terminal directory to it
2. `cmake <path to root of the project psql_tools>`
3. `make extension.hive_fork`
4. `make install`

The extension will be installed in the directory `<postgres_shareddir>/extension`. You can check the directory with `pg_config --sharedir`.

To start using the extension in a database, execute psql command: `CREATE EXTENSION hive_fork`

### Alternatively, you can manually execute the SQL scripts to directly install the fork manager
The required ordering of the sql scripts is included in the cmake file [src/hive_fork/CMakeLists.txt](./CMakeLists.txt).
Execute each script one-by-one with `psql` as in this example: `psql -d my_db_name -a -f  context_rewind/data_schema.sql`
 
## Architecture
All elements of the fork manager are placed in a schema called 'hive'.

The fork manager is written using an "events source" architecture style. This means that during live sync, hived only schedules events (by writing to the database), and then applications process them at their own pace (by using fork manager API queries to get alerted whenever hived has modified the block data).

The fork manager is designed to work with [transaction isolation level](https://www.postgresql.org/docs/10/transaction-iso.html) `READ COMMITTED`, which is the default for PostgreSQL.

The fork manager enables multiple Hive applications to use a single block database and process blocks completely independently of each other (applications do not need to place locks on the share blockchain data tables).

Hive block data is stored in two separated, but similar tables: irreversible and reversible blocks.

An application groups its tables into a named context. A context name can only be composed of alphanumerical characters and underscores. An application's context holds information about its processed events, blocks, and the fork which is now being processed by the application. These pieces of information
are enough to automatically create views which combine irreversible and reversible blocks data seamlessly for application queries. The auto-constructed view names use the following template: 'hive.{context_name}_{blocks|transactions|multi_signatures|operations}_view'.

### Overview of the fork manager and its interactions with applications and hived
![alt text](./doc/evq_c3.png )

### Hived block-processing algorithm
![alt text](./doc/evq_hived_process_blocks.png)


### Requirements for an application algorithm using the fork manager API
![alt text](./doc/evq_app_process_block.png)

Any application must first create a context, then create its tables which inherit from `hive.base`.

An application calls `hive.app_next_block` to get the next block number to process. If NULL was returned, an application must immediatly call `hive.app_next_block` again. Note: the application will automatically be blocked when it calls `hive.app_next_block` if there are no blocks to process. 

When a range of block numbers is returned by app_next_block, the application may edit its own tables and use the appropriate snapshot of the blocks
data by querying the 'hive.{context_name}_{ blocks | transactions | operations | transactions_multisig }' views. These view present a data snapshot for the first block in the returned block range. If the number of blocks in the returned range is large, then it may be more efficient for the application to do a "massive sync" instead of syncing block-by-block.

To perform a massive sync, the application should detach the context, execute its sync algorithm using the block data, then reattach the context. This will eliminate the performance overhead associated with the  triggers installed by the fork manager that monitor changes to the application's tables.

### Non-forking applications
It is expected that some applications will only want to process irreversible blocks, and therefore don't require the overhead associating with fork switching. Such an application should not register any table in its context. A context without registered tables (aka an 'irreversible context') will traverse only irreversible block data. This means that calls to `hive.app_next_block` will return only the range of irreversible blocks which are not already processed or NULL. Similarly, the set of views for an irreversible context only deliver a snapshot of irreversible data up to the block already processed by the application.

In summary, a non-forking application is coded in much the same way as a forking application (making it relatively easy to change between these two modes), but a non-forking app does not register its tables with its context and it is only served up information about irreversible blocks.

### Important notice about irreversible data
:warning: **Although reversible and irreversible block tables are directly visible to aplications, these tables should not be queried directly. It is expected that the structure of the underlying tables may change in the future, but the structure of a context's views will likely stay constant. This means that the applications which directly read the tables instead of the views may need to be refactored in the future to use newer versions of the fork manager.**

### Examples of the application
Two application examples written in Python3 were prapared. Both programs use `sqlalchemy` package as a databae engine. Programs
are very simple, both of them collect number of transaction per day - they prepare histograms in a table named `trx_histogram`.
One of the program is a non-forking application - it operates only on irreversible blocks and second application utilizes
support for blockchain forks. Applications are available here:
- forking application [doc/examples/hive_fork_app.py](./doc/examples/hive_fork_app.py)
- non-forking application [doc/examples/hive_non_fork_app.py](./doc/examples/hive_non_fork_app.py)

Actually both programs are different only in lines which create a 'trx_histogram' table - the table in forking application
inherits from`hive.base` to register it into the context. Look at the differences in diff format:
```diff
--- hive_non_fork_app.py
+++ hive_fork_app.py
@@ -6 +6 @@
-SQL_CREATE_HISTOGRAM_TABLE = """
+SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
@@ -10,0 +11 @@
+    INHERITS( hive.base )
@@ -51 +52 @@
-        db_connection.execute( SQL_CREATE_HISTOGRAM_TABLE )
+        db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )
```

:warning: At the moment there is no defined method to switch from non-forking application to forking one. This problem will be
solved together with final solution for a method to register tables into context. 


### REVERSIBLE AND IRREVERSIBLE BLOCKS
IRREVERSIBLE BLOCKS is a set of database tables for blocks which the blockchain considers irreversible - they will never change (i.e. they can no longer be reverted by a fork switch).
These tables are defined in [src/hive_fork/irreversible_blocks.sql](./irreversible_blocks.sql)

REVERSIBLE BLOCKS is a set of database tables for blocks which could still be reverted by a fork switch.
These tables are defined in [src/hive_fork/reversible_blocks.sql](./reversible_blocks.sql)

Each application should work on a snapshot of block information, which is a combination of reversible and irreversible information based on the current status of the application's context (status being the state of the application's last processed block and the associated fork for that block).

Because applications may work at different speeds, the fork manager has to hold reversible blocks information for every block and fork not already processed by any of the applications. This requires an efficient data structure. Fortunately the solution is quite simple - it is enough to add
a fork id to the block data inserted by hived to the irreversible blocks table. The fork manager manages forks ids - 
information about each fork is stored in the hive.fork table. When 'hived' pushes a new block with a call to `hive.push_block`, the fork manager adds information about the current fork to a new reversible data row. Reversible data tables are presented in a generalised form in the example below:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    1    |  DATA_21  |
|    3     |    1    |  DATA_31  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |
|    4     |    2    |  DATA_42  |
|    4     |    3    |  DATA_43  |

If an application is working on fork=2 and block_num=3 (this information is held by `hive.context` ), then its snapshot of data for the example above is:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |

This means that the snaphot of data for an application with context `app_context` can be obtained by filtering  blocks and forks with a relativly simple SQL query like:
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
Remark: The fork_id is not a part of the real blockchain data, it is an artifact created by the fork manager, and may differ across instances of an application running in different databases.

### EVENTS QUEUE
The events queue is a table defined in [src/hive_fork/events_queue.sql](./events_queue.sql). Each row in the table represents an event. Each event is defined with its **id**, **type** and BIGINT **block_num** value. The `block_num` value has different meaning for different types of events:

|   event type     | block_num meaning                                           |
|----------------- |-------------------------------------------------------------|
| BACK_FROM_FORK   | fork id of corresponding entry in `hive.fork`               |
| NEW_BLOCK        | number of the new block                                     |
| NEW_IRREVERSIBLE | number of the latest irreversible block                     |
| MASSIVE_SYNC     | the highest number of blocks pushed massively by hived node |

Events are ordered by the **id**, thus events that happen earlier have lower ids than subsequent events. The events queue is traversed by an application when it calls `hive.app_next_block` - the lowest event from all events with an id higher than the `event_id` stored in the application's context is chosen and processed, and at the end the context's 'event_id' is updated.

#### Optimizaton of forks
There are situations when an application doesn't have to traverse the events queue and process all the events. When there are `BACK_FROM_FORK` events ahead of a context's `event_id`, then the application can ignore all events before the fork with lower `block_num` (because all such blocks have been reverted by a fork switch). Here is a diagram to show this situation:
![](./doc/evq_events_optimization.png)

The optimization above is implemented in [src/hive_fork/app_api_impl.sql](./app_api_impl.sql) in function `hive.squash_events` (which is automatically called by the `hive.app_next_block` function).

#### Removing obsolete events
Once a block becomes irreversible, events related to that block which have been processed by all contexts (applications) are no longer needed by applications. These events are automatcially removed from the events queue by the function `hive.set_irreversible` (this function is periodically called by hived when the last irreversible block number changes).


### CONTEXT REWIND
Context_rewind is the part of the fork manager which is responsible for registering application tables and the saving/rewinding  operation on the tables to handle fork switching.

Applications and hived shall not use directly any function from the [src/hive_fork/context_rewind](./context_rewind/) directory.

An application must register any of its tables which are dependant on changes to hive blocks.
Any table is automatically registered during its creation only when it inherits from hive.base. 
A table is registered into the most recently created context (*this aspect of the design may change, still under discussion*). If there is no context, an exception is thrown.

```
CREATE TABLE table1( id INTEGER ) INHERITS( hive.base )
```
hive.base table is defined here: [context_rewind/data_schema.sql](./context_rewind/data_schema.sql).

Data from 'hive.base' is used by the fork manager to rewind operations. Column 'hive_rowid'
is used by the system to distinguish between edited rows. During registration, a set of triggers are
enabled on a table that record any changes. 

Moreover a new table is created - a shadow table whose structure is a copy of the registered table + columns for operation registered tables. A shadow table is the place where triggers record changes to the associated application table. A shadow table is created in the 'hive' schema and its name is created using the rule below:
```
hive.shadow_<table_schema>_<table_name>
```
It is possible to rewind all operations registered in shadow tables with `hive.context_back_from_fork`

Because the triggers add some significant overhead when modifying application tables, in some situations it may be necessary to temporary disable the triggers for the sake of better performance. To do this there are functions: 
* `hive.detach_table` to disable triggers
* 'hive.attach_table' to enable triggers. 

When triggers are disabled, no support for fork management is enabled for a table,
so the application should solve the situation. In most cases this should only be done when blocks older than the last irreversible block are being processed, so no forks can happen there.

It is quite possible that applications which use the fork system will want to change the structure of the registered tables. This is possible only when coresponding shadow tables are empty. This means, before an upgrade, the application must be in a state in which there is no pending fork. The system will block ( raise an exception ) 'ALTER TABLE' command if the corresponding shadow table is not empty.

When a table is edited, its shadow table is automatically adapted to the new structure (the old shadow table is dropped and a new one is created with the new structure).

## Database structure
### Fork manager
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
After finishing a massive push of blocks, hived will invoke this method to schedlue MASSIVE_SYNC event. The parameter `_block_num`
is a last massivly synced block - head or irreversible blocks.

#### APP API
The functions which should be used by an application

##### hive.app_create_context( _name )
Creates a new context. Context name can contains only characters from set: `a-zA-Z0-9_`

##### hive.app_next_block( _context_name )
Returns `hive.blocks_range` -range of blocks numbers to process or NULL
It is a most important function for any application.
To ensure correct work of fork rewind mechanism any application must process returned blocks and modify their tables according to block chain state on time where the returned block is a head block.

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
1. Constraints FOREIGN KEY must be DEFERRABLE, otherwise we cannot guarnteen success or rewinding changes - the process may temporary violates tables constraints.
   More informations about DEFERRABLE constraint can be found in PosgreSQL documentaion for [CREATE TABLE](https://www.postgresql.org/docs/10/sql-createtable.html)
   and [SET CONSTRAINTS](https://www.postgresql.org/docs/10/sql-set-constraints.html)

## Other architectures which were abandoned
### C++-based extension for fork management
There was a hope that an extension written in C/C++ can be more performant and that access to a lower level of PostgreSQL could give some benefits.

The most important problem faced by the fork manager is to rewind reversible changes in a way which does not violate constraints on the application tables. The C++-based extension was implemented by encoding changed blobs of rows from the registered tables into byte arrays and saving them in a separated table in the order in which the changes occurred (actually a stack of changed rows was implemented). The extension was
implemented and then abandoned with the [commit](https://gitlab.syncad.com/hive/psql_tools/-/commit/e6ac13be5d137fe0de5d7fe916905a9b97a11bdc).

There were a few reasons to retreat from the C/C++-based fork manager extension:
1. The extension could cause a crash not only in the client connection but also in the main PostgreSQL server process (this occurred multiple times during development).
2. The documentation for PostgreSQL C interface is terse, and for some details PostgresSQL source code needed to be analyzed.
3. There was a doubt about portability of such an extension between different versions of PostgreSQL, indeed the extension was working with PostgreSQL 10, but did not work with PostgreSQL 13.
4. It turned out that it was impossible to execute some actions only with the C iterface and executing some SQL queries from the C++ code was required.
5. It turned out that the C/C++ extension was slower than the current SQL implementation in every test. The report is [here](https://gitlab.syncad.com/hive/psql_tools/-/blob/c1140df5f72a29df4d3d26d95f63e52595702c3c/doc/Performance.md)
6. The C/C++ version was more complicated than the SQL version. The implementation of rewinding reversible operations in C++ took more than 3 weeks, whereas implementation of similar functionality with SQL took a week.
   
### SQL extension with one stack of changes ( no shadow tables )
It turned out that it is impossible to implement with SQL a similar stack of changed rows as was implemented in the C++ extension.

There is no method to take and save a blob of a table's row in a generic form, so it is not possible to have a common table for all changes from different tables.


### SQL extension without events queue
When the SQL method of rewinding reversible tables was implemented (this part is now named `context_rewind`), there was a noble idea to use it for rewinding both the applications tables and the tables filled directly by hived. This would make for a relatively simple implementation of the whole extension - hived would have its tables registered in its context and in case of a fork switch, the block tables would be reverted.

Unfortunately, during analysis, it was found that this kind of architecture will require the use of locks on hived's tables to solve race condition between reading of hived tables by the applications and modifications to them by hived. 

Introducing locking would make hived's operation dependent on the quality of the applications operating on the data - how fast they will commit transactions to release their locks on the data being written by hived. Moreover, the applications become dependant on each other, because one application may block hived and other applications would then not get new live blocks while that application blocked hived.
