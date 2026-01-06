#! /bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

# Script reponsible for setup of specified postgres instance.
#
# - creates all builtin HAfAH roles on pointed PostgreSQL server instance

# Download create_haf_app_role.sh from common-ci-configuration if not present locally
# Note: create_haf_app_role.sh handles its own common.sh dependency via built-in fallback
ensure_haf_scripts() {
    local haf_path="$1"
    local scripts_dir="$haf_path/scripts"
    local script="create_haf_app_role.sh"
    local common_ci_ref="${COMMON_CI_REF:-develop}"
    local script_url="https://gitlab.syncad.com/hive/common-ci-configuration/-/raw/${common_ci_ref}/haf-app-tools/scripts/${script}"

    if [[ ! -f "$scripts_dir/$script" ]]; then
        echo "HAF script not found locally, downloading from common-ci-configuration (ref: $common_ci_ref)..."
        mkdir -p "$scripts_dir"
        if command -v curl &> /dev/null; then
            curl -fsSL "$script_url" -o "$scripts_dir/$script"
        elif command -v wget &> /dev/null; then
            wget -q "$script_url" -O "$scripts_dir/$script"
        else
            echo "ERROR: Neither curl nor wget is available. Please install one to download HAF scripts."
            exit 1
        fi
        chmod +x "$scripts_dir/$script"
        echo "HAF script downloaded successfully."
    fi
}

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to setup a pointed PostgreSQL instance for HAF installation"
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL   Allows to specify a PostgreSQL URL (in opposite to separate --host and --port options)"
    echo "  --path-to-haf=PATH   Allows to specify a path to HAF installation (defaults to the parent directory of this script)"
    echo "  --help               Display this help screen and exit"
    echo
}

supplement_builtin_roles() {
  local pg_access="$1"
  echo "Attempting to supplement definition of HAfAH builtin roles..."
  psql "$pg_access" -v ON_ERROR_STOP=on -c 'GRANT hafah_owner TO haf_admin;'
  psql "$pg_access" -v ON_ERROR_STOP=on -c 'GRANT hafah_user TO haf_admin;'
}

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_URL=""
HAF_PATH="$SCRIPTPATH/../haf"

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
    --path-to-haf=*)
        HAF_PATH="${1#*=}"
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
  POSTGRES_ACCESS="postgresql://haf_admin@${POSTGRES_HOST}:${POSTGRES_PORT}/haf_block_log"
else
  POSTGRES_ACCESS=$POSTGRES_URL
fi

ensure_haf_scripts "$HAF_PATH"

"$HAF_PATH/scripts/create_haf_app_role.sh" --postgres-url="$POSTGRES_ACCESS" --haf-app-account="hafah_owner"
"$HAF_PATH/scripts/create_haf_app_role.sh" --postgres-url="$POSTGRES_ACCESS" --haf-app-account="hafah_user"

supplement_builtin_roles "$POSTGRES_ACCESS"
