#!/usr/bin/env bash
# performance.shape.apply (.aidev/project.yaml): installs this tree's database code
# on a copy of the db-shape, the way scripts/install_app.sh installs it.
#
#   AIDEV_DB_SHAPE_PSQL=<psql invocation reading SQL on stdin> .aidev/shape-apply.sh
#
# The shape server has no network, so install_app.sh cannot be given a DSN: it runs
# unchanged from a scratch copy of the sources with .aidev/shape-psql.sh first on
# PATH as `psql`, which feeds each of its psql calls to $AIDEV_DB_SHAPE_PSQL on
# stdin. The files, their order and the statements between them are therefore
# install_app.sh's own. As in run-checks.sh, the copy keeps the install log and the
# version file out of the tree.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${AIDEV_DB_SHAPE_PSQL:?set by aidev db shape: the psql invocation reaching the shape copy}"
: "${AIDEV_DB_SHAPE_DATABASE:?set by aidev db shape: the shape copy psql reaches}"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -r db backend endpoints scripts "$stage/"
hash="$(git rev-parse HEAD 2>/dev/null || echo aidev)"
printf "TRUNCATE TABLE hafah_backend.version; INSERT INTO hafah_backend.version(git_hash) VALUES ('%s');\n" \
    "$hash" > "$stage/scripts/set_version_in_sql.pgsql"
mkdir "$stage/bin"
ln -s "$PWD/.aidev/shape-psql.sh" "$stage/bin/psql"

# A shape restores the source's hafah schemas owned by postgres, and db/hafah_app.sql
# drops and creates them as hafah_owner: drop them first, as the shape's superuser,
# and let the app's roles create schemas in the copy (the shape restores the roles).
shape_psql=()
eval "shape_psql=($AIDEV_DB_SHAPE_PSQL)"
"${shape_psql[@]}" -v ON_ERROR_STOP=1 -v db="$AIDEV_DB_SHAPE_DATABASE" <<'SQL'
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS hafah_endpoints CASCADE;
DROP SCHEMA IF EXISTS hafah_backend CASCADE;
GRANT CREATE, CONNECT ON DATABASE :"db" TO hafah_owner, hafah_user;
SQL

(cd "$stage" && PATH="$stage/bin:$PATH" bash scripts/install_app.sh)
