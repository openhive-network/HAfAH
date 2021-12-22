#!/bin/bash

DB_URL=$1 							# ex. postgresql://postgres:pass@127.0.0.1:5432/hafah
PORT=$2									# ex. 8095
OUTPUT_LOG=dump.log
PERFORMANCE_OUTPUT=raw_performance_data.csv
PROCESSED_PERFORMANCE_OUTPUT=performance.csv
ROOT_DIR=$PWD

if [ "$#" -gt 2 ]; then
    ROOT_DIR=$3
    echo "setting custom HAfAH root project directory to $ROOT_DIR"
fi

rm -f $OUTPUT_LOG $PERFORMANCE_OUTPUT

echo 'runnning server...'
$ROOT_DIR/main.py -p $DB_URL -n $PORT | tee -i $OUTPUT_LOG
echo 'processing output...'
$ROOT_DIR/tests/performance/parse_server_output.py $OUTPUT_LOG $PROCESSED_PERFORMANCE_OUTPUT
echo 'done.'
