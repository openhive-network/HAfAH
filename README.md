**Abstract**: This repository contains tests for API. All API tests are currently 
  grouped for these served by hived  and these served by hivemind. The goal is to 
  have flat list of the tests and start their subsets separatly by hived and 
  hivemind CI processes.

# Usage:
## Installing pyrest test framework
### By `pip3`
`pip3 install pyresttest`

### From sources
```
git clone https://github.com/svanoort/pyresttest.git
cd pyresttest
python3 setupt.py build
python3 setup.py install --user
```

### Remarks
If you are not installing by `pip3` make sure that you have installed `pyyaml`, `future`, `pycurl`
in your system. Also you will need developer libs for `libcurl4-openssl`, `libssl` (for Ubuntu `libcurl4-openssl-dev` and `libssl-dev`)

## Usage with `hived`:
### Python API tests:
Runnable with `ctest` (TODO)

### PyRest API tests:
Node address is defined inside bash script.

a) API tests with `equal` comparator (using strict equal on query result and pattern):
`./run_api_tests.sh equal`

b) API tests with `contain` comparator (check if result contain pattern):
`./run_api_tests.sh contain`

## Usage with `hivemind`:
### Python API tests:
Runnable with `ctest` (TODO)

## PyRest API tests:
In tests directory we have two bash scripts:
* `run_api_tests.sh` - for running api tests,
* `run_api_benchmarks.sh` - for running benchmarks

Examples of running tests:

a) API tests in directory `full_sync` with `equal` comparator (using strict equal on query result and pattern):
`./run_api_tests.sh https://api.hive.blog full_sync equal`

b) API tests in directory `full_sync` with `contain` comparator (check if result contain pattern):
`./run_api_tests.sh https://api.hive.blog full_sync contain`

Examples of running benchmarks:

`./run_api_benchmarks.sh https://api.hive.blog`

## Tavern API tests:
To run tavern test:
1. Enter `tavern` directory
2. Edit `common.yaml` and set variables to desired values
3. Install tavern/pytest `python3 -m pip install tavern[pytest]`
4. Run all tests:
```
export HIVEMIND_ADDRESS=127.0.0.1
export HIVEMIND_PORT=8080
PYTHONPATH=$PYTHONPATH:$(pwd) pytest -v -n auto --durations=0 .
```
5. Run tests from given directory
```
PYTHONPATH=$PYTHONPATH:$(pwd) pytest -v -n auto --durations=0 <directory_name>
```

To Run Tavern full sync with specified URL PORT for hivemind node, that checks if API call returns results use:
```
./scripts/run_tests_full_sync.sh URL PORT
```

To Run Tavern full sync for pattern tests without checking patterns use:
```
./scripts/run_full_sync_tests.sh URL PORT ../tavern/
```

Remarks:
- To increase verbosity use `-vv` option instead of `-v`.
- `durations` option gives time measurement for tests, set to `0` will show durations of all tests. `Number` greater than zero will show only `number` slowest tests.
- `-n` option allows to run tests on multiple cores, `auto` will use all available cores