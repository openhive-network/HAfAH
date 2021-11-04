Following pseudocode explains how a hafah algorithm works.

#***********MAIN-ALGORITHM***********

while (cond)                          #when `allowed-empty-results`=-1 then `cond`==True , otherwise `cond` is dependent on value of `allowed-empty-results`.
                                      #When number of empty results that were taken from HAF is greater than `allowed-empty-results` value, then this loop finishes
  force attaching context             #forcing, because previous closing of app could have failed. At the beginning whole app has to be attached( required by HAF )
  SQL: hive.app_next_block            #returns {first_block;last_block}
  calculate `block_ranges`            #divide a range {first_block;last_block} into `N` smaller ranges, every contains `range-blocks-flush` blocks
  if _last_block - _first_block > 0:  #MASSIVE sync
    SQL: hive.app_context_detach      #required by HAF
    WORK-ALGORITHM                    #below explained
    SQL: hive.app_context_attach      #required by HAF
  else:                               #LIVE sync
    WORK-ALGORITHM                    #below explained

#***********WORK-ALGORITHM***********
launch ThreadPoolExecutor(with 2 workers):                    #here are processed sub-algorithms(sending, processing) in 2 threads
  RECEIVE-ALGORITHM
  SEND-ALGORITHM

#***********RECEIVE-ALGORITHM***********
while `block_ranges` is not empty:                            #the collection `block_ranges` was created in main-algorithm loop
  `ACTUAL-RANGE` = get the smallest range from `block_ranges` #the smallest, because processing blocks is from 1 up to HEAD
  remove `ACTUAL-RANGE` from `block_ranges`                   #it's not needed anymore
  calculate `sub_block_ranges_1`                              #divide `ACTUAL-RANGE` into `threads-receive` elements. Every thread will be process own parts of blocks
  launch ThreadPoolExecutor(with `threads-receive` workers):  #here is getting data from a database in many threads.
    call `get_impacted_accounts` pear every thread            #there are returned all impacted accounts for every operation, f.e. for `transfer` operation 2 accounts are returned
    wait until all threads finish                             #waiting is necessary, because an order of operations is crucial. It's used in `account_operations` table
    while limit of stored operations is reached:              #the limit `1mln` operations is set directly in an application
        wait 1 second                                         #better to wait than to store huge amount of data in RAM
    put result into BUFFER-QUEUE                              #`BUFFER-QUEUE -  collection needed in producer(receiver from database)/consumer(sender into database) type algorithm.

#***********SEND-ALGORITHM***********
while(True)                                                   #`forever` because reading is dependent on signal from a receiver. When it emits a signal about the end, then this loop finishes.
  while(wait for data)                                        #if there isn't any data in `BUFFER-QUEUE` an excepton `queue.Empty` is thrown and listening carries on
    get data from BUFFER-QUEUE                                #getting an information about impacted accounts and after that `BUFFER-QUEUE` removed current element
    prepare data for valid SQL query                          #prepare collections with whole information about accounts/operations. This information will be needed so as to prepare SQL queries
    launch ThreadPoolExecutor(with `1` worker):               #here is sending query to a database
      SQL: `INSERT INTO accounts`                             #execute SQL query
    calculate `sub_block_ranges_2`                            #divide information about operations for given accounts into small parts. Every thread will be process own parts of blocks
    launch ThreadPoolExecutor(with `threads-send` workers):   #here is sending query to a database
      SQL: `INSERT INTO account_operations`                   #execute SQL query - every thread has own part of data
    if mode is not massive-mod:                               #only when MASSIVE mode exists
      SQL: hive.app_context_detached_save_block_num           #when everything was written correctly last processed block is written. It's a protection against failure.
                                                              #From point of view performance, better is to start from blocks that were processed already.
