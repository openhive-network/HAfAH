# Benchmarks

This directory contains inputs and programs to benchmark any API.

It requires jmeter to work, which can be set up using `./setup_jmeter.bash` script

To benchmark API's you can use jmeter with pre-configured `jmx` files (jmeter test plans), which you can find in `./performance_data/<api name>/JMX/*.jmx` or you can use `./benchmark.py` script.

`benchmark.py` script is based on `csv` input files, which provides input queries for API's. For performance testing of block_api on 5M local node on 8090 port, just type:


```
./benchmark.py -n blocks_api -p 8090 -c perf_5M_light.csv
```

For same test but on remote machine:

```
./benchmark.py -n blocks_api -p 8090 -c perf_5M_light.csv -a hive-6.pl.syncad.com
```

To list available csv inputs, use `-l` flag + `-n` with api name (by default `account_history_api`), for output like this

```
./benchmark.py -l

# output

...
2022-08-04 15:34:26,279 - performance - INFO - Found and avaiable csv's:

perf_5M_light.csv
cl_60M_prod_jrpc.csv
perf_5M_heavy.csv
cl_60M_custom_jrpc.csv
perf_60M_light.csv
perf_60M_heavy.csv

```

Basing on csv filename script decides how to prepare jmeter and how to run test. Here is legend (which can be expanded in future), what specific csv do

modes:

    cl -        constant load, CSV files marked like this will be executed in infinite loop to generate constant load
    perf -      performance, if CSV file is marked with perf, it will serve as provider of 500 lines, if file contain less, it will loop around file

attributes:

    60M -       amount of blocks, this defines, how many blocks has to be available when testing
    heavy -     provides samples with a lot of return data (e.x. huge blocks)
    light -     provides samples which processing times should be very low
    prod -      if CSV file is tagged with this, that means it was generated basing on real calls from production
    psql -      [cl only] CSV is prepared as postgres input
    jrpc -      [cl only] CSV is prepared as jsonrpc call input
    custom -    [cl only] CSV file is custom


If you want to add new csv, make sure to keep filename properly:

```
<mode>_<amount of blocks>M_<tag 1>_<tag 2>_<tag N>.csv
```


