Following pseudocode explains how a hafah algorithm works. This algorithm consists of 2 following elements:
#***********AH-ALGORITHM***********
PREPARE-ALGORITHM
MAIN-ALGORITHM

#***********PREPARE-ALGORITHM***********
if SQL: app_context_exists:           #always it's necessary to check if AH context exists
  remove redundant operations         #Sometimes a situation can happen that some blocks were processed, but `detached_block_num`(an auxiliary value from `hive.contexts` table) field wasn't changed due to the crash.
                                      #So at the beginning data from blocks that are higher than `detached_block_num` value are removed.
else:
  SQL: app_create_context             #create new context
  SQL: create tables                  #create 2 tables: `accounts`, `account_operations`
  SQL: create API functions           #create some functions needed for API calls: `get_ops_in_block`, `get_transaction`, `get_ops_in_transaction`, `enum_virtual_ops`
receive accounts                      #fill a dictionary with accounts
receive account operations            #find last number of operation for every account

#***********MAIN-ALGORITHM***********
while (cond)                                      #when `allowed-empty-results`=-1 then `cond`==True , otherwise `cond` is dependent on value of `allowed-empty-results`
                                                  #When number of empty results that were taken from HAF is greater than `allowed-empty-results` value, then this loop finishes
  force attaching context                         #forcing, because previous closing of app could have failed. At the beginning whole app has to be attached( required by HAF )
  SQL: hive.app_next_block                        #returns {first_block;last_block}
  calculate `block_ranges`                        #divide a range {first_block;last_block} into `N` smaller ranges, every contains 40k blocks
  if _last_block - _first_block > 0:              #MASSIVE sync
    SQL: hive.app_context_detach                  #required by HAF
    if _last_block - _first_block > 20mln blocks: #20 mln blocks - this threshold is set empirically
      remove constraints                          #remove indexes so as to improve performance
    else:
      add constraints                             #add indexes if they don't exist
    WORK-ALGORITHM                                #below explained
    SQL: hive.app_context_attach                  #required by HAF
  else:                                           #LIVE sync
    add constraints                               #add indexes if they don't exist
    WORK-ALGORITHM                                #below explained

#***********WORK-ALGORITHM***********
launch ThreadPoolExecutor(with 2 workers):                    #here are processed sub-algorithms(sending, processing) in 2 threads
  RECEIVE-ALGORITHM
  SEND-ALGORITHM

#***********RECEIVE-ALGORITHM***********
                                                              #During receiving data threads are used, because getting impacted accounts is a bottleneck,
                                                              #so threads are a simple solution how to improve performance.
                                                              #If every chunk is f.e. `N` blocks length, so it's easy to divide this chunk into f.e. `K` threads.

while `block_ranges` is not empty:                            #the collection `block_ranges` was created in main-algorithm loop
  `ACTUAL-RANGE` = get the smallest range from `block_ranges` #the smallest, because processing blocks is from 1 up to HEAD
  remove `ACTUAL-RANGE` from `block_ranges`                   #it's not needed anymore
  calculate `sub_block_ranges_1`                              #divide `ACTUAL-RANGE` into `threads-receive` elements. Every thread will be process own parts of blocks
  launch ThreadPoolExecutor(with `threads-receive` workers):  #here is getting data from a database in many threads
    call `get_impacted_accounts` per every thread             #there are returned all impacted accounts for every operation, f.e. for `transfer` operation 2 accounts are returned
    wait for all threads                                      #waiting is necessary, because an order of pairs [impacted account;operation] is crucial. Gathered data is used in `account_operations` table
      wait until subsequent thread finishes                   #wait for result from particular thread
      while limit of stored operations is reached:            #the limit `3mln` pairs [impacted account;operation] is set directly in an application
        wait 1 second                                         #better to wait than to store huge amount of data in RAM
      put result into BUFFER-QUEUE                            #`BUFFER-QUEUE -  collection needed in producer(receiver from database)/consumer(sender into database) type algorithm

#***********SEND-ALGORITHM***********
while(True)                                                   #`forever` because reading is dependent on signal from a receiver. When it emits a signal about the end, then this loop finishes
  while(wait for data)                                        #if there isn't any data in `BUFFER-QUEUE` an exception `queue.Empty` is thrown and listening carries on
    get data from BUFFER-QUEUE                                #get an information about pairs [impacted account;operation] and after that remove from `BUFFER-QUEUE`
    prepare data for valid SQL query                          #prepare collections with whole information about accounts/operations. This information will be needed so as to prepare SQL queries
    calculate `sub_block_ranges_2`                            #divide information with pairs [impacted account;operation] into small parts. Every thread will be process own parts of data
    launch ThreadPoolExecutor(with `threads-send` workers):   #here is sending query to a database
      SQL: `INSERT INTO accounts`                             #execute SQL query - is merged to a query from first thread. This is relatively a small query, so lack of any performance impact
      SQL: `INSERT INTO account_operations`                   #execute SQL query - every thread has own part of data
    if mode is not massive-mod:                               #only when MASSIVE mode exists
      SQL: hive.app_context_detached_save_block_num           #when everything was written correctly last processed block is written. It's a protection against failure
                                                              #because from point of view performance, better is to start from blocks that were processed already
