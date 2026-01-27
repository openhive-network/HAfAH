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

echo "Installing app..."

# Create database roles and schemas
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../db/builtin_roles.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../db/hafah_app.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET custom.swagger_url = '$SWAGGER_URL';" -f "$SCRIPTPATH/../endpoints/endpoint_schema.sql"

# Backend: argument parsing and common utilities
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/argument_parsing.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/json_utils.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/bit_operations.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/validation.sql"

# Backend: JSON-RPC functions
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/ops_in_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/transaction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/virtual_ops.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/account_history.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/jsonrpc/json_formatters.sql"

# Endpoint types
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/operation.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/sort_direction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/transaction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/fill_order.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/types/participation_mode.sql"

# Backend: REST utilities
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/exceptions.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/validators.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/account.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/get_operation_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/paging.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/path_filters.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/operation_body_filter.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/common/utilities/function_helpers.sql"

# Backend: REST implementations
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/account_history.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/by_operations.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/default.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/excluding_accounts.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/including_accounts.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/include_account.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/account_history/filtering_functions/exclude_account.sql"

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/market_history/recent_trades.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/market_history/trade_history.sql"

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/blocks/block_header.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/blocks/block_range.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/blocks/block.sql"

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/operations/acc_op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/operations/op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/operations/operation.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../backend/rest/operations/ops_in_block.sql"

# JSON-RPC dispatcher and version
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/dispatcher.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/set_version_in_sql.pgsql"

# REST endpoints
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/blocks/get_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/blocks/get_block_range.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/blocks/get_block_header.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/blocks/get_ops_by_block_paging.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/transactions/get_transaction.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/accounts/get_ops_by_account.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/accounts/get_acc_op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/operations/get_operations.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/operations/get_operation.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/operation_types/get_op_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/operation_types/get_operation_keys.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/other/get_version.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/other/get_head_block_num.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/other/get_block.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/market_history/get_recent_trades.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f "$SCRIPTPATH/../endpoints/market_history/get_trade_history.sql"

# Configure permissions
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET ROLE hafah_owner;GRANT USAGE ON SCHEMA hafah_endpoints TO hafah_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET ROLE hafah_owner;GRANT USAGE ON SCHEMA hafah_backend TO hafah_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET ROLE hafah_owner;GRANT SELECT ON ALL TABLES IN SCHEMA hafah_endpoints TO hafah_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET ROLE hafah_owner;GRANT SELECT ON ALL TABLES IN SCHEMA hafah_backend TO hafah_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET ROLE hafah_owner;GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hafah_backend TO hafah_user;"

# Create is_setup_completed function (must be at the very end)
# This signals that setup is complete and hafah_user has all required access
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on <<EOF
SET ROLE hafah_owner;
CREATE OR REPLACE FUNCTION hafah_backend.is_setup_completed()
RETURNS BOOLEAN
IMMUTABLE
LANGUAGE PLPGSQL
AS \$\$
BEGIN
  RETURN TRUE;
END
\$\$;
EOF
