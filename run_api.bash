#!/bin/bash

DB_URL=$1 							# ex. postgresql://postgres:pass@127.0.0.1:5432/hafah
PORT=$2									# ex. 8095
OUTPUT_LOG=dump.log

screen -L -Logfile $OUTPUT_LOG -mdS HAfAH ./main.py -p $DB_URL -n $PORT
echo "output from HAfAH: $OUTPUT_LOG"

# to get to 20 worst SQL times execute command below
# grep '###' ${OUTPUT_LOG} | cut -d '|' -f 2: | sort -r -n | head -n 20
