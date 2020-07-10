* Abstract: * This repository contains tests for API. All API tests are currently 
  grouped for these served by hived  and these served by hivemind. The goal is to 
  have flat list of the tests and start their subsets separatly by hived and 
  hivemind CI processes.

= Usage:
== Usage with `hived`:
=== Python API tests:
Runnable with `ctest` (TODO)
=== PyRest API tests:
Node address is defined inside bash script.
a) API tests with `equal` comparator (using strict equal on query result and pattern):
`./run_api_tests.sh equal`

b) API tests with `contain` comparator (check if result contain pattern):
`./run_api_tests.sh contain`

== Usage with `hivemind`:
=== Python API tests:
Runnable with `ctest` (TODO)

=== PyRest API tests:
In tests directory we have two bash scripts `run_api_tests.sh` and `run_api_benchmarks.sh`. 
Examples of running scripts:
a) API tests with `equal` comparator (using strict equal on query result and pattern):
`./run_api_tests.sh https://api.hive.blog equal`

b) API tests with `contain` comparator (check if result contain pattern):
`./run_api_tests.sh https://api.hive.blog contain`

c) Benchmarks:
`./run_api_benchmarks.sh https://api.hive.blog`

