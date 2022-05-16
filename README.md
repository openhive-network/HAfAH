## Requirements

Python: `python3.8+`

## Starting `HAfAH`
---

### python version

> :warning: Before starting app or __load tests__, install required packages!

```
python3 -m pip install --user -r requirements.txt
```

To start application execute following command:

```
./main.py -p postgresql://<user>:<password>@127.0.0.1:5432/<db_name> -n 8095
```

### postgREST version

To start using this version, first create API and install postgREST locally with

```
./run.sh setup
```

Then start server 

```
./run.sh start <PORT>
```

`PORT` is optional, default is 3000.
<br><br>

## Running load tests
---

### 0. Setup

Required packages: `wget` `unzip` `openjdk-11-jre` `openjdk-11-jdk`

In folder you want execute theese commands to download and setup jmeter

```
# download jmeter
wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.4.3.zip >> /dev/null
unzip apache-*.zip >> /dev/null
rm apache-*.zip && mv apache* apache

# download java postgres library
pushd apache && pushd lib
wget https://jdbc.postgresql.org/download/postgresql-42.3.1.jar >> /dev/null
popd

# this  will install jmeter in system, so you don't have to pass path to jmeter binary with every perf. test
sudo ln -s $PWD/bin/jmeter /usr/bin/jmeter
popd
```

<br>

### 1. Info


1. Run python HAfAH (in this example on port 8095)
2. Run postgREST HAfAH (in this example on port 3000)
3. Run hived (in this example on http port 8091)
4. Start load tests by executing:


`./tests/performance_test.py` script.

Here is `--help`:

```
$ ./tests/performance_test.py --help
usage: performance_test.py [-h] [-l [LIST_CSV]] [-c SELECT_CSV] [-r ROOT_DIR] [-p PORT] [-a ADDR] [-s TOP_SLOWEST]
                           [-d DATADIR] [-t THREADS] [-j JMETER] [--postgres POSTGRES_URL] [--no-launch [NO_HAFAH]]

optional arguments:
  -h, --help            show this help message and exit
  -l [LIST_CSV], --list [LIST_CSV]
                        if specified program will just list avaiable CSV files
  -c SELECT_CSV, --csv SELECT_CSV
                        selected CSV FILENAME (use -l to list avaiable), [default=perf_60M_heavy.csv]
  -r ROOT_DIR, --root-dir ROOT_DIR
                        path to root directory of HAfAH project [default=/home/hive/hf/HAfAH]
  -p PORT, --port PORT  port to start HAfAH instance, and perform test; set to 5432 for direct postgres query
                        [default=8095]
  -a ADDR, --address ADDR
                        addres to connect during test [default=localhost]
  -s TOP_SLOWEST, --top-slowest TOP_SLOWEST
                        defines amount of top slowest calls to show [default=5]
  -d DATADIR, --datadir DATADIR
                        defines path to workdir (path to this dir will alway be recreated) [default=./wdir]
  -t THREADS, --threads THREADS
                        defines amount of threads to use during tests [default=10]
  -j JMETER, --jmeter JMETER
                        path to jmeter executable [default=/usr/bin/jmeter]
  --postgres POSTGRES_URL
                        if specified connection string, tests will be performed on postgres db
                        [default=postgresql:///haf_block_log]
  --no-launch [NO_HAFAH]
                        if specified, no HAfAH instance will be launched (if specified, no full data will be avaiable)
                        [default=False]
```

<br>

### 2. Managing input data for performance test

- ### LISTING

To list avaiable inputs execute

```
./tests/performance_test.py -l
```

this will provide following output:

```
2022-04-08 14:13:27,065 - performance - INFO - Found and avaiable csv's:
cl_60M_prod_jrpc.csv     -      for generating load on 60M http server
perf_5M_heavy.csv        -      for generating load on 5M http server
cl_60M_custom_jrpc.csv   -      for generating load on 60M http server
perf_60M_light.csv       -      for generating load on 60M http server
perf_60M_heavy.csv       -      for generating load on 60M http server


legend:
cl - constant load, CSV files marked like this will be executed in infinite loop to generate constant load
perf - performance, if CSV file is marked with perf, it will serve as provider of 500 lines, if file contain less, it will loop aroung file
60M - amount of blocks, this defines, how many bloacks has to be avaiable when testing
heavy - [perf only] this tag is for CSV files, which provides samples with a lot of return data (e.x. huge blocks)
light - [perf only] this tag is for CSV files, which provides samples which processing times should be very low
prod - [cl only] if CSV file is tagged with this, that means it was generated basing on real calls from production
psql - [cl only] CSV is prepared as postgres input
jrpc - [cl only] CSV is prepared as jsonrpc call input
custom - [cl only] CSV file is custom
```

As You can read, there is convention on naming configurations. There are two modes:

First is `PERF` with `perf_` prefix in `csv` input file. In this mode program will start HAfAH
and run 500 queries from given file (if less, then looping over file) __on each__ thread.
After this, there will be displayed statistics for each endpoint. If HAfAH was started with this script,
there will be also more detailed statistics, like complete CSV report and top 5 slowest calls per endpoint

FORMAT:

```
<get_ops_in_block|enum_virtual_ops_begin>;<enum_virtual_ops_end>;<get_account_history>;<get_transaction>
```
Example:
```
2889001;2889005;frankjones;ef73d8fadf17e2590c6d96efc1ca868edd7dd613
2889002;2889006;cheetah18;02b3404402bc68314daa3752833f8c8c14daa070
2889003;2889007;shrooms;ee1e29958549b9547383c3ef932bd95a571fd0d4
2889004;2889008;littlekitty;8dfe0564434071b76276fc7892505a397f2fef98
```

<br>

Second one is `CL` with `cl_` prefix in `csv` input file. In this mode program will run as long as
there is no keyboard interruption (ctrl+c). After this small summary is genmerated.

FORMAT:

```
<endpoint>|<body>
```

Example:

```
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
get_transaction|{"jsonrpc": "2.0", "method": "account_history_api.get_transaction", "params": {"id":...}
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
```

> :warning: Pay attention that `PERF` format can be used both way: for http and SQL performing, while `CL` requires specialization


- ### SELECTING

To select input for performance testing use `-c` flag and put __just filename__ as argument:

```
./tests/performance_test.py -c perf_5M_heavy.csv
```

- #### ADDING

To add new file, just create file in `HAfAH/tests/performance_data/CSV` with `csv` extension.
Name of such file should match following convention: `<mode>_<required blocks>M_<tags underline separated...>.csv`.
If you want to add new tag, just remember to add it to legend in script.

### 3. Starting examples

- I want to start standard test on fully synced DB, but in custom workdir:

```
./tests/performance_test.py --postgres $POSTGRES_URL -d path/to/my/workdir
```

- I want to start standard test on fully synced DB, but on already runni	ng instance

```
./tests/performance_test.py -p $PORT_OF_INSTANCE --no-launch
```

- I want to use 32 threads during test on 5M DB, which is on other server:

```
./tests/performance_test.py -c perf_5M_heavy.csv -t 32 -a other.machine.com
```

- I didn't installed jmeter and wnat to run simple test

```
./tests/performance_test.py --postgres $POSTGRES_URL -j $PATH_TO_JMETER_BIN
```

- I want 3 most slowest queries and start HAfAH on non-default 7312 port

```
./tests/performance_test.py --postgres $POSTGRES_URL -p 7312 -s 3
```

### 4. Columns in generated report

Path to report is always displayed, and it's located in workdir with name like: `report_<port>.csv`
It is `|` separated and contains following columns:

- endpoint				-	name of endpoint that was tested. e.g: `get_ops_in_block`
- identifier			-	it's position of samplewith format: `<thread no [1-N]>/<sample num [1-500]>`

values below are in miliseconds.
theese columns are result of parsing HAfAH log:

- hafah_receive		-	time of receiving request
- hafah_SQL				-	time of executing query
- hafah_backend		-	time of additional processing by python
- hafah_dispatch		-	time of handling request by `jsonrpcserver` library
- hafah_sending		-	time of serialization and sending response from HAfAH to jmeter
- hafah_processing	-	leftover time, during handling whole request
- hafah_total			-	sum of all times above

this column is result of parsing jmeter log:

- jmeter_elapsed		-	time of request by jmeter

- query					-	SQL query extracted from HAfAH log

###  5. Interpreting results in `index.html`
---

`APDEX` - application performance index for endpoint<br>
`Statistics` - stats of response times (avg, min, max, median, percentiles)<br>
`Charts` -> `Response Times` - charts of response time distribution, percentiles, relation to thread number<br>
