
How to do a synchronization:
./ah-v5.py --url postgresql://LOGIN:PASSWORD@HOST/DATABASE_NAME --schema-dir ./queries --range-blocks-flush 40000 --allowed-empty-results 0 --threads-receive 7 --threads-send 7

Scripts - a quick explanation:
ah-v2.py - uses `multiprocessing.Pool`
ah-v3.py - uses `ThreadPoolExecutor - it's always generated new db-connection`
ah-v4.py - uses `ThreadPoolExecutor - uses pool of db-connection`
ah-v5.py - uses `ProcessPoolExecutor`

Experiments:

RAM:        32GB
Processor:  AMD Ryzen 7 5800X 8-Core Processor

Time for synchronization of 5mln blocks:
*********************
(`multiprocessing.Pool`)
~270s

(`ThreadPoolExecutor - it's always generated new db-connection`)
~260s

(`ThreadPoolExecutor - uses pool of db-connection`)
242s

(`ProcessPoolExecutor`)
279s
*********************
