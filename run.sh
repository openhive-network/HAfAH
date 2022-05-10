#!/bin/bash

set -e
set -o pipefail

echo_success() {
    echo 'SUCCESS: Users and API recreated'
}

create_ah_schema(){
    psql -d haf_block_log -f "queries/ah_schema_functions.pgsql"
}

create_api() {
    postgrest_dir=$PWD/postgrest
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $postgrest_dir/hafah_backend.sql
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $postgrest_dir/hafah_endpoints.sql
}

start_webserver() {
    postgrest postgrest.conf
}

test_patterns() {
    port=$1
    cd $PWD/haf/hive
    
    ./tests/api_tests/pattern_tests/run_tests.sh $port $PWD
}

postgrest_v=9.0.0
jmeter_v=5.4.3

if [ "$1" = "start" ]; then
    start_webserver
elif [ "$1" = "re-start" ]; then
    create_ah_schema
    create_api
    echo_success
    start_webserver
elif [ "$1" =  "test-patterns" ]; then
    test_patterns ${@:2}
else
    echo "job not found"
    exit 1
fi;