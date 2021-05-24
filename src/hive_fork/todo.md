#TODO LIST
Contains list of task to be done to finish implementation of hive_fork postgres extension.
Striked out tasks are already done.

1. ~~**context_rewind** update context rewind subsystem api to hive_fork requirements~~
2. ~~**schema** add required tables (reversible/irreversible blocks, events queue, app_contexts)~~ 
1. ~~**hived_api** **push_block** insert block into reversible blocks~~
2. ~~**hived_api** **push_block** insert event into events queue~~
3. ~~**hived_api** **back_from_fork** insert event into events queue~~
4. ~~**hived_api** **set_irreversible** insert event into events queue~~
7. ~~**app_api** **app_create_context** create function and context with context_rewind api~~
7. ~~**app_api** **app_create_context** create blocks view for each context~~   
5. ~~**hived_api** **set_irreversible** clean up obsolete events~~
6. ~~**hived_api** **set_irreversible** copy reversible blocks into irreversible~~
8. **app_api** **app_next_block** process NEW_BLOCK event
9. **app_api** **app_next_block** process BACK_FROM_FORK_EVENT event
10. **app_api** **app_next_block** process NEW_IRREVERSIBLE event
11. **app_api** **app_next_block** update APP_CONTEXT
11. **start/restart** problem with starting, closing and restarting hived and hive_fork
12. testing, testing, testing...
13. optimizations to save space for blocks and events_queue tables 
14. testing, testing...
