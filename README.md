# HAfAH

Hafah is a HAF-based app that implements the "account history API" for hive. It is a web server that responds to account history REST calls using data stored in a [HAF database](https://gitlab.syncad.com/hive/haf).

Currently, hafah is a "read-only" HAF application: it writes no data to the HAF database, so it doesn't require a "replay" of blockchain history before it can start serving data (all the data it needs is available in the base-layer HAF tables).

Like all standardized HAF apps, the server should be started using the dedicated application role being created during application deployment. By default, for HAFAH this role is; `hafah_user`. To perform application setup, you need to use dedicated HAF administration role: `haf_admin`. This database role is created by default as part of the setup of the HAF database that your HAF apps interact with. But if you are running with a non-dockerized HAF database, you will need to configure some form of authentication for this role (e.g. a password for the role or use unix-account based authorization).

Like HAF itself, you can install hafah directly on your computer, or you can run it inside a docker. In either case, it will then need to communicate with your HAF database as described further below.

## Option 1: Starting `HAfAH` directly on host

### postgREST version

To start using this version, first create API and install postgREST locally with

```bash
./run.sh setup
```

Then start server:

```bash
./run.sh start <PORT>
```

`PORT` is optional, default is 3000.

## Option 2: Starting a `HAfAH` using prebuilt docker container (preferred way)

Instead of running hafah servers directly, you can run them inside dockers. For many users, especially ones that are running their HAF database inside a docker, this is the recommended method, because it eliminates the need to manually configure authentication of hafah's connection to the HAF database. To run the application server inside a docker:

Perform application installation step into specified HAF database:

```bash
docker run --rm -it --name HAFAH-setup registry.gitlab.syncad.com/hive/hafah:COMMIT_SHA install_app --postgres-url=postgresql://haf_admin@172.17.0.1:5432/haf_block_log
```

Once application installation will complete (docker container will finish its execution), go to the next step.

Run the postgrest server inside a docker (to accept API requests on specified port):

```bash
docker run --rm -it --name Postgrest-HAFAH-instance -p 8081:6543 -e POSTGRES_URL=postgresql://hafah_user@172.17.0.1:5432/haf_block_log registry.gitlab.syncad.com/hive/hafah:COMMIT_SHA
```

The first number specified by the -p option is the external port you want to use (8081 for the postgrest server in the examples above). The second number speciefied by the -p option is the internal port that the hafah server is listening to inside the docker. **This second value is fixed by the configuration of the docker image, so it must be set to 6543.**

POSTGRES_URL is an environment variable, which should point to the PostgreSQL cluster for your HAF database. By default, the auto-created hafah_user role should be used for the connection to your HAF database for the Postgrest-HAFAH-instance and haf_admin to use a HAFAH-setup container (which performs an installation of uninstallation).

### Important note before using above example commands: PostgreSQL authorization

If you are using a dockerized HAF instance and a dockerized hafah server, the haf docker will have preconfigured authorization settings (defined in its own pg_hba.conf file) to allow trusted authentication to `haf_block_log` database using `haf_admin` role when connections come in from the docker network. Configuration for `hafah_user` role must be done manually. By default, IP addresses for the docker network will be assigned in the 172.0.0.0 network class.

If you are directly hosting your PostgreSQL instance (i.e. it's not running in a docker), you will need to configure a way to authenticate connections by the `haf_admin` and `hafah_user` roles. In particular, if you are running your hafah server in a docker, you will need to configure your HAF postgres cluster to listen on the docker network. Below is an example of how to configure authentication:

- Modify the `postgres.conf` file to listen on either the docker network OR all network interfaces:

```properties
listen_addresses = '172.17.0.1'    #listen on just docker network
```

```properties
listen_addresses = '*'             #listen on all network interfaces (including docker network)
```

- Add an entry to the `pg_hba.conf` file to allow authentication of `haf_admin` and `hafah_user` to the haf_block_log database by connections coming from the docker network (or alternatively, all network interfaces):

```properties
host    haf_block_log             haf_admin    172.0.0.0/0          trust    #allow connection from docker
host    haf_block_log             hafah_user   172.0.0.0/0          trust    #allow connection from docker
```

```properties
host    haf_block_log             haf_admin    0.0.0.0/0            trust    #allow connection from all
host    haf_block_log             hafah_user   0.0.0.0/0            trust    #allow connection from all
```

WARNING: above example is only specific for testing and fast-deployment purposes. To ensure a secure deployment, consult PostgreSQL documentation related to authentication methods (e.g. peer-based authentication and its interaction with UNIX accounts).

### Instead of running prebuilt images, one can build their own using `build_instance.sh` script provided in the repo

Before starting the build, be sure that you cloned git repo together with submodules (easiest way is to use `--recurse-submodules` option directly passed to `git clone`).

The command to build HAfAH Docker image is as follows:

```bash
scripts/ci-helpers/build_instance.sh "postgrest-latest" . registry.gitlab.syncad.com/hive/hafah \
  --http-port=80 \
  --haf-postgres-url=postgresql://haf_admin@haf-instance:5432/haf_block_log
```

Parameters are:

- `--http-port=PORT`           HTTP port to be used by HAfAH (default: 6543)
- `--haf-postgres-url=URL`     HAF PostgreSQL URL, (default: postgresql://haf_app_admin@172.17.0.1:5432/haf_block_log)
- `-?/--help`                  Print help screen and exit

## Running load tests

### 0. Setup

Required packages: `wget` `unzip` `openjdk-11-jre` `openjdk-11-jdk`

In folder you want execute theese commands to download and setup jmeter

```bash
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

### 1. Info

1. Run postgREST HAfAH (in this example on port 3000)
2. Run hived (in this example on http port 8091)
3. Start load tests by executing:

`./tests/performance_test.py` script.

Here is `--help`:

```bash
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

### 2. Managing input data for performance test

- ### LISTING

To list avaiable inputs execute

```bash
./tests/performance_test.py -l
```

this will provide following output:

```bash
2022-04-08 14:13:27,065 - performance - INFO - Found and available csv's:
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

```bash
<get_ops_in_block|enum_virtual_ops_begin>;<enum_virtual_ops_end>;<get_account_history>;<get_transaction>
```

Example:

```bash
2889001;2889005;frankjones;ef73d8fadf17e2590c6d96efc1ca868edd7dd613
2889002;2889006;cheetah18;02b3404402bc68314daa3752833f8c8c14daa070
2889003;2889007;shrooms;ee1e29958549b9547383c3ef932bd95a571fd0d4
2889004;2889008;littlekitty;8dfe0564434071b76276fc7892505a397f2fef98
```

Second one is `CL` with `cl_` prefix in `csv` input file. In this mode program will run as long as
there is no keyboard interruption (ctrl+c). After this small summary is genmerated.

FORMAT:

```bash
<endpoint>|<body>
```

Example:

```bash
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
get_transaction|{"jsonrpc": "2.0", "method": "account_history_api.get_transaction", "params": {"id":...}
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
get_account_history|{"jsonrpc": "2.0", "method": "account_history_api.get_account_history", "params": {"opera...}
```

> :warning: Pay attention that `PERF` format can be used both way: for http and SQL performing, while `CL` requires specialization

- ### SELECTING

To select input for performance testing use `-c` flag and put __just filename__ as argument:

```bash
./tests/performance_test.py -c perf_5M_heavy.csv
```

- #### ADDING

To add new file, just create file in `HAfAH/tests/performance_data/CSV` with `csv` extension.
Name of such file should match following convention: `<mode>_<required blocks>M_<tags underline separated...>.csv`.
If you want to add new tag, just remember to add it to legend in script.

### 3. Starting examples

- I want to start standard test on fully synced DB, but in custom workdir:

```bash
./tests/performance_test.py --postgres $POSTGRES_URL -d path/to/my/workdir
```

- I want to start standard test on fully synced DB, but on already runni	ng instance

```bash
./tests/performance_test.py -p $PORT_OF_INSTANCE --no-launch
```

- I want to use 32 threads during test on 5M DB, which is on other server:

```bash
./tests/performance_test.py -c perf_5M_heavy.csv -t 32 -a other.machine.com
```

- I didn't installed jmeter and wnat to run simple test

```bash
./tests/performance_test.py --postgres $POSTGRES_URL -j $PATH_TO_JMETER_BIN
```

- I want 3 most slowest queries and start HAfAH on non-default 7312 port

```bash
./tests/performance_test.py --postgres $POSTGRES_URL -p 7312 -s 3
```

### 4. Columns in generated report

Path to report is always displayed, and it's located in workdir with name like: `report_<port>.csv`
It is `|` separated and contains following columns:

- endpoint        - name of endpoint that was tested. e.g: `get_ops_in_block`
- identifier      - it's position of samplewith format: `<thread no [1-N]>/<sample num [1-500]>`

values below are in miliseconds.
theese columns are result of parsing HAfAH log:

- hafah_receive    - time of receiving request
- hafah_SQL        - time of executing query
- hafah_backend    - time of additional processing by python
- hafah_dispatch   - time of handling request by `jsonrpcserver` library
- hafah_sending    - time of serialization and sending response from HAfAH to jmeter
- hafah_processing - leftover time, during handling whole request
- hafah_total      - sum of all times above

this column is result of parsing jmeter log:

- jmeter_elapsed   - time of request by jmeter

- query            - SQL query extracted from HAfAH log

### 5. Interpreting results in `index.html`

`APDEX` - application performance index for endpoint  
`Statistics` - stats of response times (avg, min, max, median, percentiles)  
`Charts` -> `Response Times` - charts of response time distribution, percentiles, relation to thread number  

## HAFAH REST

### 1. Blocks

```bash
- /blocks?from-block&to-block&search-params Get blocks from given range (get_block_range)
- /blocks/{block-num} Block details (get_block)
- /blocks/{block-num}/header Header in referenced block (get_block_header)
- /blocks/{block-num}/operations List of operations for given block (get_ops_in_block)
```

### 2. Transactions

```bash
- /transactions/{transaction-id} Get transaction (get_transaction)
```

### 3. Operations

```bash
- /operations?from-block&to-block&search-params Search for operations (get_ops_in_block in range)
- /operations/virtual?from-block&to-block&search-params Enum virtua operation as search (enum_virtual_ops)
```

### 4. Account

```bash
- /accounts/{account-name}/operations Get operations for given account (get_account_history)
```

### 5. Other

```bash
- /version (No corresponding method)
```
