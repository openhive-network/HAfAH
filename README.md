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
	- :warning: **before you run jmeter load tests** make sure to increase jvm heap size by setting env `JAVA_ARGS='-Xms4g  -Xmx4g'` or by editing jmeter (.../bin/jmeter:166)
	- it's java based, so you'll probably need to install openjdk


2. Run HAfAH (in this example on port 8095)
3. Run hived (in this example on http port 8091)
4. Start load tests by executting:

```
./tests/performance/run_perf_tests.bash /path/to/extracted/apache-jmeter-*/bin/bin/jmeter /path/to/performance/directory <1'st port to benchmark> [<N port to benchmark> ... ]
```

Example:
```
./tests/performance/run_perf_tests.bash $JMETER $PWD/tests/performance 8091 8095
```

`note`: paths should be absolute

5. When load tests are ready, path to `csv` file will be printed
6. If you need worst execution times of SQL queries here is handy command:

```
grep SQL /path/to/log/from/HAfAH | cut -d '|' -f 2: | sort -r -n | head -n 20
```

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


## Parsing without `run_api.bash` script
---

`$SERVER_OUTPUT` - path to file with output of server<br>
`$PARSED_OUTPUT` - path to file, where parsed output will be stored<br><br>

```
./tests/performance/parse_server_output.py $SERVER_OUTPUT $PARSED_OUTPUT
```
