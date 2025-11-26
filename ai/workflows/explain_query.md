Description: Analyze a queries performance

1. Run a cold_start workflow on the remote_server.
2. Write the query with an EXPLAIN ANALYZE to the remote_server's /haf-pool/haf-datadir directory (the docker maps this to its internal /home/hived/datadir).
If the query is expected to take longer than 60 seconds, drop the ANALYZE option from the explain.
3. Run the query on the remote-server using ssh remote-server "docker exec haf-haf-1 psql -f /home/hived/datadir/query.sql".
4. Return the explain analyze results.
