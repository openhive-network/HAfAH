#!/usr/bin/env bash
# The step functions are called indirectly, through `step`.
# shellcheck disable=SC2317,SC2329
# The checks AIDEV's verification slots run (.aidev/project.yaml), as one junit
# report per suite: each named step is a test case, its log the failure body.
#
#   .aidev/run-checks.sh <suite> <step>...
#
#   - shellcheck      ShellCheck at error severity on scripts/ and docker/, and at
#                     the default severity on .aidev/'s own scripts
#   - sql-registered  every .sql file under db/, backend/ and endpoints/ is applied
#                     by scripts/install_app.sh (a file it misses never reaches a
#                     database)
#   - install         scripts/install_app.sh into the stack's HAF database
#                     (HAFAH_TEST_DB_HOST, default `haf`)
#   - reinstall       scripts/uninstall_app.sh, then install_app.sh again
#   - api-smoke       PostgREST over the installed schema, JSON-RPC and REST calls
#                     checked by .aidev/hafah_smoke.py; one junit case per call
#
# install, reinstall and api-smoke need the HAF stack (.aidev/test-stack.compose.yml).
# Reports go to test-results/<suite>/: junit.xml (one case per step) plus
# api-smoke.xml.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

suite="${1:?usage: $0 <suite> <step>...}"; shift
out="test-results/$suite"
rm -rf "$out"; mkdir -p "$out"
cases="$out/cases.tsv"; : > "$cases"

DB_HOST="${HAFAH_TEST_DB_HOST:-haf}"
ADMIN_URL="postgresql://haf_admin@$DB_HOST/haf_block_log"
export HAFAH_TEST_ADMIN_URL="$ADMIN_URL"
export HAFAH_TEST_USER_URL="postgresql://hafah_user@$DB_HOST/haf_block_log"

status=0
# record CASES_FILE NAME RC SECONDS LOG
record() {
    if [ "$3" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$2" "$4" >> "$1"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$2" "$4" "$3" "$5" >> "$1"
    fi
}

step() {
    local name="$1"; shift
    local log="$out/$name.log" t0=$SECONDS rc=0
    echo "== $name" >&2
    "$@" > "$log" 2>&1 < /dev/null || rc=$?
    [ "$rc" -eq 0 ] || { status=1; tail -40 "$log" >&2; }
    record "$cases" "$name" "$rc" "$((SECONDS - t0))" "$log"
}

run_shellcheck() {
    shellcheck --version | head -2
    # The project's scripts carry warnings today; errors are the floor.
    shellcheck -S error -f gcc scripts/*.sh scripts/*.bash docker/*.sh || return 1
    shellcheck -f gcc .aidev/*.sh .aidev/runtime/*.sh
}

sql_registered() {
    local f missing=0
    while IFS= read -r f; do
        if ! grep -qF "/../$f\"" scripts/install_app.sh; then
            echo "not applied by scripts/install_app.sh: $f"
            missing=1
        fi
    done < <(find db backend endpoints -name '*.sql' | sort)
    [ "$missing" -eq 0 ] && echo "every .sql file under db/, backend/ and endpoints/ is applied"
    return "$missing"
}

# The install scripts write their log and the version file next to themselves, and
# the version file comes from git, which a workflow checkout may not have: stage
# the sources in a scratch directory and write the version there.
stage=""
stage_sources() {
    [ -n "$stage" ] && return 0
    stage="$(mktemp -d)"
    cp -r db backend endpoints scripts "$stage/"
    local hash
    hash="$(git rev-parse HEAD 2>/dev/null || echo aidev)"
    printf "TRUNCATE TABLE hafah_backend.version; INSERT INTO hafah_backend.version(git_hash) VALUES ('%s');\n" \
        "$hash" > "$stage/scripts/set_version_in_sql.pgsql"
}

wait_for_db() {
    local i
    for i in $(seq 60); do
        psql "$ADMIN_URL" -Atc "select 1" >/dev/null 2>&1 && return 0
        echo "waiting for $ADMIN_URL ($i)"
        sleep 5
    done
    psql "$ADMIN_URL" -Atc "select 1"
}

install() {
    stage_sources && wait_for_db || return 1
    (cd "$stage" && bash scripts/install_app.sh --postgres-url="$ADMIN_URL") || return 1
    psql "$ADMIN_URL" -v ON_ERROR_STOP=on -Atc "select hafah_backend.is_setup_completed()"
}

reinstall() {
    stage_sources && wait_for_db || return 1
    (cd "$stage" && bash scripts/uninstall_app.sh --postgres-url="$ADMIN_URL") || return 1
    install
}

for s in "$@"; do
    case "$s" in
        shellcheck) step shellcheck run_shellcheck ;;
        sql-registered) step sql-registered sql_registered ;;
        install) step install install ;;
        reinstall) step reinstall reinstall ;;
        api-smoke) step api-smoke python3 .aidev/hafah_smoke.py "$out" ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done
[ -n "$stage" ] && rm -rf "$stage"
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
