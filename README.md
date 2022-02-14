## Starting `HAfAH`
---
To start application just execute following command:

```
./main.py -p postgresql://<user>:<password>@127.0.0.1:5432/<db_name> -n 8095
```

or use ready scipt, which runs program and after closing (^C) it run script that parse logs (into performance.csv). handy for integration with jmeter

```
./run_api.bash postgresql://<user>:<password>@127.0.0.1:5432/<db_name> 8095
```

<br><br>

## Running load tests
---



1. Download and extract [jmeter](https://jmeter.apache.org/download_jmeter.cgi)
	- :rotating_light: **before you run jmeter load tests** make sure to increase jvm heap size by setting env `JAVA_ARGS='-Xms4g -Xmx4g'` or by editing jmeter (.../bin/jmeter:166)
	- it's java based, so you'll probably need to install openjdk (recomended: `openjdk-11-jre` and `openjdk-11-jdk`)


2. Run python HAfAH (in this example on port 8095)
3. Run postgREST HAfAH (in this example on port 3000)
4. Run hived (in this example on http port 8091)
5. Start load tests by executing:

```
./tests/performance/run_perf_tests.bash /path/to/extracted/apache-jmeter-*/bin/bin/jmeter /path/to/performance/directory <1'st port to benchmark> [<N port to benchmark> ... ]
```

Example:
```
./tests/performance/run_perf_tests.bash $JMETER $PWD/tests/performance hived 8091 python 8095 postgrest 3000
```

:memo: paths should be absolute

6. When load tests are ready, path to `csv` file will be printed
7. If you need worst execution times of SQL queries here is handy command:

```
grep SQL /path/to/log/from/HAfAH | cut -d '|' -f 2: | sort -r -n | head -n 20
```
8. When passing `postgres 5432` as arguments, jmeter will call SQL directly, but you need specify those envs:

```
PSQL_USER
PSQL_PASS
PSQL_DBNAME
```

and optionally `PSQL_HOST`, which is defaulted to `127.0.0.1`.

Example:

	PSQL_USER=some_user PSQL_PASS=some_password PSQL_DBNAME=hafah ./tests/performance/run_perf_tests.bash $JMETER $PWD/tests/performance/ postgres 5432 hived 8091 python 8095 postgrest 3000

`run_perf_tests.bash` will generate Apache JMeter Dashboard with performance stats in `workdir/report_${PORT}/index.html`.

## Interpretting results in `parsed.csv`
---

`sample_id` - global sequential mesurement for whole test <br>
`body` - JSON that can be pasted to curl or insomnia <br>
`sql` - SQL that was performed (only get_transaction has a bit modified query) <br>
`result_<port>.jtl` - contains average duration of whole call from all 10 threads in miliseconds for given port


## Interpreting results in `performance.csv`
---

`endpoint` - name oif endpoint that was tested<br>
`probe no.` - number of probe in relation to endpoint<br>
`avg. total SQL time [ms]` - average time thread spend executing sql for given probe<br>
`avg. processing time [ms]` - average time thread spend processing data from SQL + time above<br>
`avg. total time [ms]` - average time thread spend serializing and sending data + time above


## Interpreting results in `index.html`
---

`APDEX` - application performance index for endpoint<br>
`Statistics` - stats of response times (avg, min, max, median, percentiles)<br>
`Charts` -> `Response Times` - charts of response time distribution, percentiles, relation to thread number<br>


## Parsing without `run_api.bash` script
---

`$SERVER_OUTPUT` - path to file with output of server<br>
`$PARSED_OUTPUT` - path to file, where parsed output will be stored<br><br>

```
./tests/performance/parse_server_output.py $SERVER_OUTPUT $PARSED_OUTPUT
```
