#! /bin/bash

set -euo pipefail 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

# Script reponsible for setup of specified postgres instance.
#
# - creates all builtin HAfAH roles on pointed PostgreSQL server instance

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to setup a pointed PostgreSQL instance for HAF installation"
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL   Allows to specify a PostgreSQL URL (in opposite to separate --host and --port options)"
    echo "  --help               Display this help screen and exit"
    echo
}

deploy_builtin_roles() {
  local pg_access="$1"
  echo "Attempting to deploy HAfAH builtin roles..."
  psql $pg_access -v ON_ERROR_STOP=on -f $SCRIPTPATH/hafah_builtin_roles.sql
}

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --postgres-url=*)
        POSTGRES_URL="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

if [ -z "$POSTGRES_URL" ]; then
  POSTGRES_ACCESS="postgresql://hive@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"
else
  POSTGRES_ACCESS=$POSTGRES_URL
fi

deploy_builtin_roles "$POSTGRES_ACCESS"
