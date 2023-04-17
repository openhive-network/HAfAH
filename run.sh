#!/bin/bash

set -e
set -o pipefail



# Script reponsible for execution of all actions required to finish configuration of the database holding a HAF database to work correctly with HAfAH.

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_USER="haf_admin"
COMMAND=""

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --user=*)
        POSTGRES_USER="${1#*=}"
        ;;
    --c=*)
        COMMAND="${1#*=}"
        ;;
    --help)
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        exit 2
        ;;
    esac
    shift
done

export DEFAULT_POSTGREST_PORT=3000
export DEFAULT_PGRST_DB_URL="postgresql://$POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"
export PGRST_DB_URI=${3:-$DEFAULT_PGRST_DB_URL}
echo "using postgres url: $PGRST_DB_URI"

setup() {
    bash $SCRIPTS_DIR/setup_postgres.sh --postgres-url=$PGRST_DB_URI
    bash $SCRIPTS_DIR/generate_version_sql.bash $PWD "sudo --user=$POSTGRES_USER"
    bash $SCRIPTS_DIR/setup_db.sh --postgres-url=$PGRST_DB_URI
}

start_webserver() {
    export PGRST_DB_SCHEMA="hafah_endpoints"
    export PGRST_DB_ANON_ROLE="hafah_user"
    export PGRST_DB_ROOT_SPEC="home"
    export PGRST_SERVER_PORT=$1

    postgrest
}

setup_postgrest() {
    bash $SCRIPTS_DIR/setup_postgrest.sh
}

print_help() {
    echo
    echo "Usage: ./run.sh (start|setup|setup-postgrest|help) [port = $DEFAULT_POSTGREST_PORT] [postgres_url = $DEFAULT_PGRST_DB_URL]"
    echo "start - starts postgrest"
    echo "setup - setups database, by setting up roles and executing required schemas"
    echo "setup-postgrest - setups postgrest, by downloading and installing postgrest binary"
    echo "help - prints this information"
}

SCRIPTS_DIR=$PWD/scripts

if [ "$COMMAND" = "start" ]; then
    start_webserver ${2:-$DEFAULT_POSTGREST_PORT}
elif [ "$COMMAND" =  "setup" ]; then
    setup
elif [ "$COMMAND" =  "setup-postgrest" ]; then
    setup_postgrest
elif [ "$COMMAND" = "help" ]; then
    print_help
else
    echo "job not found"
    print_help
    exit 1
fi;
