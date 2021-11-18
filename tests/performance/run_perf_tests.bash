#!/bin/bash

JMETER=$1										# path to jmeter which is avaible here: https://jmeter.apache.org/download_jmeter.cgi
PATH_TO_INPUT_DIR=$2				# located in: $PROJECT_ROOT_DIR/tests/performance
PATH_TO_INPUT_CSV="$PATH_TO_INPUT_DIR/config.csv"
PATH_TO_INPUT_PROJECT_FILE="$PATH_TO_INPUT_DIR/proj.jmx.in"
PATH_TO_PARSE_SCRIPT="$PATH_TO_INPUT_DIR/parse.py"

if [ -z "$THREADS_COUNT" ]; then
  THREADS_COUNT=10
fi

if [ ! -f $JMETER ]; then
	echo "jmeter binary at given address: '$JMETER' not found!"
	exit -1
fi

if [ ! -d "$PATH_TO_INPUT_DIR" ]; then
	echo "$PATH_TO_INPUT_DIR does not exists"
	exit -2
fi

if [[ ! "$PATH_TO_INPUT_DIR" = /* ]]; then
	echo "paths should be absolute!"
	exit -3
fi


generate_output() {
  # JMETER=$1
  PORT=$1

  OUTPUT_PROJECT_FILE=out_$PORT.jmx
  OUTPUT_REPORT_FILE=result_$PORT.jtl

  echo "configuring test..."
  sed "s/ENTER PORT NUMBER HERE/$PORT/g" $PATH_TO_INPUT_PROJECT_FILE > $OUTPUT_PROJECT_FILE.v00
  sed "s/ENTER THREAD COUNT HERE/$THREADS_COUNT/g" $OUTPUT_PROJECT_FILE.v00 > $OUTPUT_PROJECT_FILE.v0
  sed "s|ENTER PATH TO CSV HERE|$PATH_TO_INPUT_CSV|g" $OUTPUT_PROJECT_FILE.v0 > $OUTPUT_PROJECT_FILE
  if [ $PORT == 5432 ]; then
    sed "s/ENTER POSTGRES USER HERE/$PSQL_USER/g" $OUTPUT_PROJECT_FILE > $OUTPUT_PROJECT_FILE.v2
    sed "s/ENTER POSTGRES PASSWORD HERE/$PSQL_PASS/g" $OUTPUT_PROJECT_FILE.v2 > $OUTPUT_PROJECT_FILE.v3
    sed "s/ENTER DATABASE NAME HERE/$PSQL_DATABASE_NAME/g" $OUTPUT_PROJECT_FILE.v3 > $OUTPUT_PROJECT_FILE.v4

    if [[ -z "$PSQL_HOST" ]]; then
      PSQL_HOST=127.0.0.1
    fi
    sed "s/ENTER POSTGRES ADDRESS HERE/$PSQL_HOST/g" $OUTPUT_PROJECT_FILE.v4 > $OUTPUT_PROJECT_FILE
    PSQL_HOST=''
    rm $OUTPUT_PROJECT_FILE.v2 $OUTPUT_PROJECT_FILE.v3 $OUTPUT_PROJECT_FILE.v4
  fi
  rm $OUTPUT_PROJECT_FILE.v0

  echo "running test..."
  rm -f $OUTPUT_REPORT_FILE
  $JMETER -n -t $OUTPUT_PROJECT_FILE -l $OUTPUT_REPORT_FILE 2>&1 | grep 'Warning' -v
}

mkdir -p workdir
pushd workdir

ARGUMENTS=""
for ((i=3; i<=$#; i++))
do
  PORT=${!i}
  generate_output $PORT
  ARGUMENTS="$ARGUMENTS result_$PORT.jtl"
done

$PATH_TO_PARSE_SCRIPT $PATH_TO_INPUT_CSV $ARGUMENTS && echo "summary: $PWD/parsed.csv"

popd
