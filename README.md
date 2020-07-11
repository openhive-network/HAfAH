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

