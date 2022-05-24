#! /bin/bash

# usage: ./generate_version_sql.bash root_project_dir

set -euo pipefail

path_to_sql_version_file="$1/set_version_in_sql.pgsql"

# acquiring hash without git
GIT_HASH=`cat $1/.git/HEAD | cut -d ' ' -f 2`
if [[ -f "$1/.git/$GIT_HASH" ]]
then
	GIT_HASH=`cat "$1/.git/$GIT_HASH"`;
fi;

echo "
CREATE SCHEMA IF NOT EXISTS hafah_private;

DROP TABLE IF EXISTS hafah_private.version;
CREATE TABLE hafah_private.version(
  git_hash TEXT
);

INSERT INTO hafah_private.version VALUES( '$GIT_HASH' );
" > $path_to_sql_version_file
