## Starting `HAfAH`
---
To start application just execute following command:

```
./main.py -p postgresql://<user>:<password>@127.0.0.1:5432/<db_name> -n 8095
```

or use ready scipt, which runs program in screen and additionally dumps all logs to `dump.log`

```
./run_api.bash postgresql://<user>:<password>@127.0.0.1:5432/<db_name> 8095
```

<br><br>

## Running load tests
---

1. Download and extract [jmeter](https://jmeter.apache.org/download_jmeter.cgi) 
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
grep SQL /path/to/log/from/HAfAH| cut -d '|' -f 2: | sort -r -n | head -n 20
```