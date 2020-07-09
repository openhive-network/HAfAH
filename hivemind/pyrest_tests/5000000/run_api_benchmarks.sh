#!/bin/bash

if [[ $# -ne 1 ]]; then 
    echo "Usage: run_api_benchmarks target_address"
    exit 1
fi

EXIT_CODE=0

echo "Running API benchmark tests\n"
pyresttest $1 ./bridge/bridge_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./condenser_api/condenser_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./database_api/database_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./follow_api/follow_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./hive_api/hive_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./tags_api/tags_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1
echo "Done!\n"

exit $EXIT_CODE