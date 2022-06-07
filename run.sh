#!/bin/bash

set -e
set -o pipefail

setup() {
    bash $SCRIPTS_DIR/setup_postgres.sh --postgres-url=$PGRST_DB_URI
    bash $SCRIPTS_DIR/setup_db.sh --postgres-url=$PGRST_DB_URI
}

start_webserver() {
    export PGRST_DB_SCHEMA="hafah_endpoints"
    export PGRST_DB_ANON_ROLE="hafah_user"
    export PGRST_DB_ROOT_SPEC="home"

    default_port=3000
    if [[ $1 == ?+([0-9]) ]]; then 
        export PGRST_SERVER_PORT=$1
    else
        export PGRST_SERVER_PORT=$default_port
    fi

    postgrest
}

setup_postgrest() {
    bash $SCRIPTS_DIR/setup_postgrest.sh
}

export PGRST_DB_URI="postgresql://haf_app_admin@/haf_block_log"

SCRIPTS_DIR=$PWD/scripts

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
