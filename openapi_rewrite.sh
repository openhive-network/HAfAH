#!/bin/bash

set -e
set -o pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"
endpoints_dir="postgrest/hafah_REST"
input_file="rewrite_rules.conf"
temp_output_file=$(mktemp)


cat <<EOF
  Script used to search for all SQL scripts with openapi descriptions...

  Usage: $0 <output_directory> <type_directories> <endpoint_directories>
  
EOF

# Default directories with fixed order if none provided
DEFAULT_OUTPUT="$SCRIPTDIR/output"

DEFAULT_ENDPOINTS="
$endpoints_dir/hafah_openapi.sql

$endpoints_dir/blocks/get_block_range.sql
$endpoints_dir/blocks/get_block.sql
$endpoints_dir/blocks/get_block_header.sql
$endpoints_dir/blocks/get_ops_in_block.sql

$endpoints_dir/operations/get_operations.sql
$endpoints_dir/operations/enum_virtual_ops.sql

$endpoints_dir/transactions/get_transaction.sql

$endpoints_dir/accounts/get_account_history.sql

$endpoints_dir/other/get_version.sql

"

echo "Using default HAF block explorer types and endpoints directories"

echo "$DEFAULT_ENDPOINTS"

# shellcheck disable=SC2086
python3 process_openapi.py $DEFAULT_OUTPUT $DEFAULT_ENDPOINTS

# Function to reverse the lines
reverse_lines() {
    awk '
    BEGIN {
        RS = ""
        FS = "\n"
    }
    {
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^#/) {
                comment = $i
            } else if ($i ~ /^rewrite/) {
                rewrite = $i
            }
        }
        if (NR > 1) {
            print ""
        }
        print comment
        print rewrite
    }' "$input_file" | tac
}

reverse_lines > "$temp_output_file"
mv "$temp_output_file" "$input_file"
