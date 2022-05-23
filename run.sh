#!/bin/bash

set -e
set -o pipefail

setup() {
    postgres_url=$(sed -rn '/^db-uri/p' $CONFIG_PATH | sed "s/db-uri//g" | sed "s/[\"\? =]//g")

    bash $SCRIPTS_DIR/setup_postgres.sh --postgres-url=$postgres_url
    bash $SCRIPTS_DIR/setup_db.sh --postgres-url=$postgres_url
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

setup_postgrest() {
    bash $SCRIPTS_DIR/setup_postgrest.sh
}

SCRIPTS_DIR=$PWD/scripts
CONFIG_PATH=$PWD/postgrest.conf

if [ "$1" = "start" ]; then
    start_webserver ${@:2}
elif [ "$1" =  "setup" ]; then
    setup
elif [ "$1" =  "setup-postgrest" ]; then
    setup_postgrest
else
    echo "job not found"
    exit 1
fi;