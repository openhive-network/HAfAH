#!/bin/bash

set -e
set -o pipefail

create_api() {
    scripts_dir=$PWD/scripts
    bash $scripts_dir/setup_postgres.sh $@
    bash $scripts_dir/setup_postgrest.sh $@
}

start_webserver() {
    default_port=3000
    if [[ $1 == ?+([0-9]) ]]; then 
        port=$1
    else
        port=$default_port
    fi

    sed -i "/server-port = /s/.*/server-port = \"$port\"/" postgrest.conf
    postgrest postgrest.conf
}

test_patterns() {
    port=$1
    cd $PWD/haf/hive
    
    ./tests/api_tests/pattern_tests/run_tests.sh $port $PWD
}

if [ "$1" = "start" ]; then
    start_webserver ${@:2}
elif [ "$1" =  "test-patterns" ]; then
    test_patterns ${@:2}
else
    echo "job not found"
    exit 1
fi;