#! /bin/bash

# usage: ./generate_version_sql.sh work_tree_dir [git_dir]
# example: ./generate_version_sql.sh $PWD
# example: ./generate_version_sql.sh /var/my/sources
# example: ./generate_version_sql.sh /sources/submodules/hafbe /sources/.git/modules/submodules/hafbe

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PATH_TO_SQL_VERSION_FILE="$SCRIPT_DIR/set_version_in_sql.pgsql"
GIT_WORK_TREE=$1
GIT_DIR=${2:-"$1/.git"}

# acquiring hash without git
GIT_HASH=$(git --git-dir="$GIT_DIR" --work-tree="$GIT_WORK_TREE" rev-parse HEAD)

echo "TRUNCATE TABLE hafah_python.version; INSERT INTO hafah_python.version(git_hash) VALUES ('$GIT_HASH');" > "$PATH_TO_SQL_VERSION_FILE"