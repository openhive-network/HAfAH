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

echo "Script parameters: $*"

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

# install_app.sh registers hafah lock-only (haf#501) where the HAF provides it; only
# its owner may unregister it, and hive.app_unregister fails for a missing row.
unregister_lock_only_app() {
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" <<'EOF'
DO $$
BEGIN
  IF to_regprocedure('hive.app_register_lock_only(text)') IS NULL THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM hafd.applications WHERE name = 'hafah' AND cardinality(contexts) = 0) THEN
    SET LOCAL ROLE hafah_owner;
    PERFORM hive.app_unregister('hafah');
    RAISE NOTICE 'Unregistered the lock-only HAF application hafah';
  END IF;
END
$$;
EOF
}

uninstall_app() {
    unregister_lock_only_app

    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS hafah_backend CASCADE;"
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS hafah_endpoints CASCADE;"

    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP OWNED BY hafah_owner CASCADE" || true
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP ROLE IF EXISTS hafah_owner"

    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP OWNED BY hafah_user CASCADE" || true
    psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -c "DROP ROLE IF EXISTS hafah_user"

}

uninstall_app
