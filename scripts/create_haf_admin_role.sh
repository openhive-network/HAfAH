#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Creates a HAF admin role for a PostgreSQL cluster."
    echo "OPTIONS:"
    echo "  --host=VALUE              Specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER             Specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --haf-admin-account=NAME  Specify an account name to be added to the `haf_administrators_group` group."
    echo "  --help                    Display this help screen and exit"
    echo
}

create_haf_admin_account() {
  local pg_access="$1"
  local haf_admin_account="$2"

  # sad, but superuser is required to set different role as a database owner...

  sudo -nu postgres psql -d postgres -aw $pg_access -v ON_ERROR_STOP=on -f - <<EOF
DO \$$
BEGIN
    CREATE ROLE $haf_admin_account WITH
      LOGIN
      SUPERUSER
      INHERIT
      CREATEDB
      NOCREATEROLE
      NOREPLICATION
      IN ROLE haf_administrators_group
      ;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE '$haf_admin_account already exists';
END
\$$;

EOF

}


HAF_ADMIN_ACCOUNT="haf_admin"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-admin-account=*)
        HAF_ADMIN_ACCOUNT="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument."
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT"

create_haf_admin_account "$POSTGRES_ACCESS" "$HAF_ADMIN_ACCOUNT"
