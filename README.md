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

## Interpretting results in CSV
---

```
|	sample_id	|	body					|	sql			|	result_8091.jtl	|	result_8095.jtl	|	result_5432.jtl	|
|-----------------------------------------------------------------------------------------------------------------------|
|	1519		|	{"jsonrpc" ... "id": 1}	|	SELECT ...;	|	6879,9			|	35768,7			|	1327,5			|
|	1919		|	{"jsonrpc" ... "id": 1}	|	SELECT ...;	|	14257,5			|	33485,3			|	1144,4			|
|	1819		|	{"jsonrpc" ... "id": 1}	|	SELECT ...;	|	7591,5			|	33112,7			|	1156,5			|
|-----------------------------------------------------------------------------------------------------------------------|
```

`sample_id` - global sequential mesurement for whole test <br>
`body` - JSON that can be pasted to curl or insomnia <br>
`sql` - SQL that was performed (only get_transaction has a bit modified query) <br>
`result_<port>.jtl` - contains average duration of whole call from all 10 threads in miliseconds for given port