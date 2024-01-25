#!/bin/bash

set -e
set -o pipefail

print_help () {
cat <<EOF
  Usage: $0 [OPTION[=VALUE]]...

  Drops database.
  OPTIONS:
    --host=VALUE             PostgreSQL host location (defaults to localhost)
    --port=NUMBER            PostgreSQL operating port (defaults to 5432)
    --postgres-url=URL       PostgreSQL URL (in opposite to separate --host and --port options)
EOF
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
    --help|-h|-?)
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
  POSTGRES_ACCESS="postgresql://haf_admin@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"
else
  POSTGRES_ACCESS=$POSTGRES_URL
fi

uninstall_app() {
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS hafah_backend CASCADE;"
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS hafah_endpoints CASCADE;"
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS hafah_python CASCADE;"

    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP OWNED BY hafah_owner CASCADE" || true
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP ROLE IF EXISTS hafah_owner"

    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP OWNED BY hafah_user CASCADE" || true
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP ROLE IF EXISTS hafah_user"

}

uninstall_app
