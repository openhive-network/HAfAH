#!/bin/bash

if [[ $# -ne 1 ]]; then 
    echo "Usage: run_api_benchmarks target_address"
    exit 1
fi

EXIT_CODE=0

echo "Running API benchmark tests"
pyresttest $1 ./benchmarks/bridge_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./benchmarks/condenser_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./benchmarks/database_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./benchmarks/follow_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./benchmarks/hive_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./benchmarks/tags_api_benchmark.yaml
[ $? -ne 0 ] && EXIT_CODE=-1
echo "Done!"

exit $EXIT_CODE