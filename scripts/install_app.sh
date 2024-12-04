#! /bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

export LOG_FILE=install_app.log
# shellcheck source=common.sh
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

# Script reponsible for execution of all actions required to finish configuration of the database holding a HAF database to work correctly with HAfAH.

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to setup a database already filled by HAF instance, to work with HAfAH application."
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL   Allows to specify a PostgreSQL URL (in opposite to separate --host and --port options)"
    echo "  --swagger-url=URL    Allows to specify a server URL"
    echo "  --help               Display this help screen and exit"
    echo
}

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_URL=""
SWAGGER_URL="{hafah-host}"

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
    --swagger-url=*)
        SWAGGER_URL="${1#*=}"
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
  POSTGRES_ACCESS="postgresql://haf_admin@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"
else
  POSTGRES_ACCESS=$POSTGRES_URL
fi

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/ah_schema_functions.pgsql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_backend.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/types/op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/types/operation.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/types/sort_direction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/types/block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/account_history.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/block_header.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/block_range.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/ops_in_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../queries/hafah_rest_backend/path_filters.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_endpoints.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/set_version_in_sql.pgsql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET custom.swagger_url = '$SWAGGER_URL';" -f "$SCRIPTPATH/../postgrest/hafah_REST/hafah_openapi.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_rest_exceptions.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/blocks/get_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/blocks/get_block_range.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/blocks/get_block_header.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/blocks/get_ops_by_block_paging.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/transactions/get_transaction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/accounts/get_ops_by_account.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/accounts/get_acc_op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/operations/get_operations.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/operations/get_operation.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/operation_types/get_op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/operation_types/get_operation_keys.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/other/get_version.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/other/get_head_block_num.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_REST/other/get_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../postgrest/hafah_roles.sql"
