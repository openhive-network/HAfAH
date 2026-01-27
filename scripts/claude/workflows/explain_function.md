---
description: Extract key internal queries from a function to get a better explain analyze. User provides a function name and a list of arguments.
---

1. Extract the key internal queries from a function, modifying the resulting queries to use the arguments provided by the user. If the user doesn't provide parameters, look at the tables to select parameter values that look likely to increase the query time. Also check the external code that calls the function to ensure there are no external limits on allowed parameters.
2. Write the query to the /haf-pool/haf-datadir directory (the docker maps this to its internal /home/hived/datadir).
3. Run EXPLAIN ANALYZE on the modified query similar to the procedure below and report the time taken by the query:
ssh remote-server "docker exec haf-haf-1 psql -f /home/hived/datadir/query.sql"