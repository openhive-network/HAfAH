#!/bin/bash

DB_URL=$1 							# ex. postgresql://postgres:pass@127.0.0.1:5432/hafah
PORT=$2								# ex. 8095
OUTPUT_LOG=dump.log
PERFORMANCE_OUTPUT=raw_performance_data.csv
PROCESSED_PERFORMANCE_OUTPUT=performance.csv
STATS_CSV_OUTPUT=stats.csv
ROOT_DIR=$PWD

rm -f $STATS_CSV_OUTPUT $PROCESSED_PERFORMANCE_OUTPUT $OUTPUT_LOG

if [ "$#" -gt 2 ]; then
	ROOT_DIR=$3
	echo "setting custom HAfAH root project directory to $ROOT_DIR"
fi

rm -f $OUTPUT_LOG $PERFORMANCE_OUTPUT

echo 'configuring server...'
./scripts/setup_.sh --postgres-url=$DB_URL
./scripts/install_app.sh --postgres-url=$DB_URL

echo 'runnning server...'
$ROOT_DIR/main.py -p $DB_URL -n $PORT | tee -i $OUTPUT_LOG
echo 'processing output...'
grep 'executed in' $OUTPUT_LOG | sed -E 's/.*DEBUG - \[(.*)\] (.*) executed in ([0-9\.,]+)ms/\1|\2|\3/g' > $STATS_CSV_OUTPUT
echo 'done.'
