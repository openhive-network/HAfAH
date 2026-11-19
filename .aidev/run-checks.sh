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
#   - install         a copy-on-write clone of the shared 5M-block HAF for this run
#                     (haf_shared.clone_run_database on AIDEV_EXTERNAL_HAF_HOST:_PORT,
#                     as haf_shared_consumer), scripts/install_app.sh into it, then the
#                     SQL checks in .aidev/*_check.sql (each rolls back what it writes)
#   - reinstall       scripts/uninstall_app.sh, then install_app.sh again, in the clone
#   - install-lock    install took HAF's exclusive hafah install lock, and install_app.sh
#                     rerun while another session holds the shared hafah lock (as a
#                     serving hafah-postgrest does) exits 0 and changes no hafah object
#   - api-smoke       PostgREST over the installed schema, JSON-RPC and REST calls
#                     checked by .aidev/hafah_smoke.py; one junit case per call
#   - tavern          the tavern pattern tests (tests/tavern) against PostgREST over
#                     the clone, by .aidev/hafah_tavern.py; one junit case per test
#   - rewriter        the rewriter tests (tests/rewriter) through the rewriter image's
#                     OpenResty and configuration (.aidev/hafah_rewriter.py) in front of
#                     PostgREST over the clone, by
#                     .aidev/hafah_rewriter_tests.py; one junit case per test
#
# install, reinstall, install-lock, api-smoke, tavern and rewriter need the shared HAF (sandbox.external haf,
# provider haf/haf); the clone is dropped when the script exits, pass or fail.
# Reports go to test-results/<suite>/: junit.xml (one case per step) plus
# api-smoke.xml, tavern.xml and rewriter.xml.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

suite="${1:?usage: $0 <suite> <step>...}"; shift
out="test-results/$suite"
rm -rf "$out"; mkdir -p "$out"
cases="$out/cases.tsv"; : > "$cases"

# The shared HAF trusts haf_shared_consumer from the fleet LAN: no password.
CONSUMER_URL="postgresql://haf_shared_consumer@${AIDEV_EXTERNAL_HAF_HOST:-}:${AIDEV_EXTERNAL_HAF_PORT:-5432}"
clone=""; clone_id=""
# The script's own stderr, which a step's redirected output does not reach: where
# the clone's name and its drop are reported.
exec 3>&2

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
    shellcheck -f gcc scripts/*.sh scripts/*.bash docker/*.sh || return 1
    shellcheck -f gcc .aidev/*.sh
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
# the sources in a scratch directory and write the version there. The shared HAF
# provides hafah_owner and hafah_user and the consumer may neither create nor drop
# roles, so the staged db/builtin_roles.sql is empty and the staged uninstall drops
# the schemas only: its DROP OWNED BY the two roles would also revoke their grants
# on every other run's clone (database privileges are cluster-wide).
stage=""
stage_sources() {
    [ -n "$stage" ] && return 0
    stage="$(mktemp -d)"
    cp -r db backend endpoints scripts "$stage/"
    echo "-- hafah_owner and hafah_user are provided by the shared HAF" > "$stage/db/builtin_roles.sql"
    sed -i '/DROP OWNED\|DROP ROLE/d' "$stage/scripts/uninstall_app.sh"
    local hash
    hash="$(git rev-parse HEAD 2>/dev/null || echo aidev)"
    printf "TRUNCATE TABLE hafah_backend.version; INSERT INTO hafah_backend.version(git_hash) VALUES ('%s');\n" \
        "$hash" > "$stage/scripts/set_version_in_sql.pgsql"
}

# This run's own clone of the shared HAF, named after the suite, the time and a
# random suffix so concurrent runs never share one.
open_clone() {
    [ -n "$clone" ] && return 0
    if [ -z "${AIDEV_EXTERNAL_HAF_HOST:-}" ]; then
        echo "AIDEV_EXTERNAL_HAF_HOST is unset: this slot needs sandbox.external haf (provider haf/haf)"
        return 1
    fi
    local run_id
    run_id="hafah-$suite-$(date -u +%Y%m%d%H%M%S)-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    clone="$(psql "$CONSUMER_URL/haf_shared" -v ON_ERROR_STOP=on -Atc "select haf_shared.clone_run_database('$run_id')")" || return 1
    clone_id="$run_id"
    export HAFAH_TEST_DB_URL="$CONSUMER_URL/$clone"
    echo "== shared HAF clone $clone ($CONSUMER_URL)" | tee /dev/fd/3
}

drop_clone() {
    [ -n "$clone" ] || return 0
    if psql "$CONSUMER_URL/haf_shared" -v ON_ERROR_STOP=on -qAtc "select haf_shared.drop_run_database('$clone_id')"; then
        echo "== dropped shared HAF clone $clone" >&3
    else
        echo "== could not drop shared HAF clone $clone; the provider reaps it after its TTL" >&3
    fi
}

cleanup() {
    drop_clone
    if [ -n "$stage" ]; then rm -rf "$stage"; fi
}
trap cleanup EXIT

install() {
    stage_sources && open_clone || return 1
    # The consumer owns the clone; the app's roles need to create its schemas in it.
    psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -c "GRANT CREATE, CONNECT ON DATABASE \"$clone\" TO hafah_owner, hafah_user" || return 1
    (cd "$stage" && bash scripts/install_app.sh --postgres-url="$HAFAH_TEST_DB_URL") || return 1
    psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -Atc "select hafah_backend.is_setup_completed()" || return 1
    local check
    for check in .aidev/*_check.sql; do
        echo "== $check"
        psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -q -f "$check" || return 1
    done
}

# Run "$@" against the installed clone; the API steps need install to have made one.
on_clone() {
    if [ -z "$clone" ]; then
        echo "no shared HAF clone: install did not run or could not create one"
        return 1
    fi
    "$@"
}

reinstall() {
    stage_sources && open_clone || return 1
    (cd "$stage" && bash scripts/uninstall_app.sh --postgres-url="$HAFAH_TEST_DB_URL") || return 1
    install
}

# Every hafah schema, function and type with the row version it was last written at:
# a rerun install that drops or replaces any of them changes this.
HAFAH_OBJECTS_SQL="select md5(string_agg(format('%s %s %s', o.oid, o.xmin, o.name), ',' order by o.oid::bigint, o.name))
from (
    select n.oid, n.xmin, n.nspname::text as name from pg_namespace n where n.nspname like 'hafah\\_%'
    union all
    select p.oid, p.xmin, p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname like 'hafah\\_%'
    union all
    select t.oid, t.xmin, t.typname::text from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname like 'hafah\\_%'
) o"

LOCK_HOLDER=hafah-lock-holder

release_lock_holder() {
    psql "$HAFAH_TEST_DB_URL" -qAtc "select pg_terminate_backend(pid) from pg_stat_activity
        where application_name = '$LOCK_HOLDER' and datname = current_database()" > /dev/null
    wait "$1" 2> /dev/null || true
}

install_lock() {
    [ -n "$clone" ] || { echo "no shared HAF clone: install did not run or could not create one"; return 1; }
    if ! grep -qF "Acquired install lock for hafah" "$out/install.log"; then
        echo "install did not run under install_with_app_lock.py holding the hafah lock (see install.log)"
        return 1
    fi

    # A HAF whose install lock reads its application registry (haf#454) installs
    # anyway, after about 10 s, while a holder holds the lock of an app no row is
    # registered under, and hafah registers none yet (it has no context to register;
    # HAfAH#113). Stand in for that registration in this run's clone so the skip is
    # what is tested; a HAF that does not read the registry needs none.
    local reads_registry
    reads_registry="$(psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -Atc "select position('hafd.applications' in prosrc) > 0
        and not exists (select 1 from hafd.applications where name = 'hafah')
        from pg_proc where oid = 'hive.try_acquire_app_install_lock(text)'::regprocedure")" || return 1
    if [ "$reads_registry" = t ]; then
        echo "== registering a stand-in hafah application: this HAF's install lock reads its registry"
        psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -q <<'SQL' || return 1
CREATE SCHEMA lock_test_hafah;
SELECT hive.app_create_context('lock_test_hafah', 'lock_test_hafah', _is_forking => FALSE, _is_attached => FALSE);
SELECT hive.app_register('hafah', ARRAY['lock_test_hafah']::hive.contexts_group);
SQL
    fi

    local before after holder rc=0 i
    before="$(psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -Atc "$HAFAH_OBJECTS_SQL")" || return 1

    psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -qAt \
        -c "SET application_name = '$LOCK_HOLDER'" \
        -c "SELECT hive.acquire_app_block_processor_locks(ARRAY['hafah'])" \
        -c "SELECT pg_sleep(600)" > /dev/null 2>&1 &
    holder=$!
    for i in $(seq 1 60); do
        [ "$(psql "$HAFAH_TEST_DB_URL" -Atc "select count(*) from pg_locks l join pg_stat_activity a on a.pid = l.pid
            where a.application_name = '$LOCK_HOLDER' and l.locktype = 'advisory' and l.mode = 'ShareLock' and l.granted")" = 1 ] && break
        if [ "$i" = 60 ]; then
            echo "$LOCK_HOLDER did not take the shared hafah lock within 30 s"
            release_lock_holder "$holder"
            return 1
        fi
        sleep 0.5
    done
    echo "== $LOCK_HOLDER holds the shared hafah lock"

    local log="$out/install-lock-rerun.log"
    (cd "$stage" && timeout 300 bash scripts/install_app.sh --postgres-url="$HAFAH_TEST_DB_URL") > "$log" 2>&1 || rc=$?
    release_lock_holder "$holder"
    cat "$log"

    after="$(psql "$HAFAH_TEST_DB_URL" -v ON_ERROR_STOP=on -Atc "$HAFAH_OBJECTS_SQL")" || return 1
    if [ "$rc" -ne 0 ]; then
        echo "install_app.sh exited $rc while the shared hafah lock was held; expected a skip with exit 0"
        return 1
    fi
    if ! grep -qF "Skipping hafah install" "$log" || grep -qF "Installing app..." "$log"; then
        echo "install_app.sh did not skip while the shared hafah lock was held"
        return 1
    fi
    if [ "$before" != "$after" ]; then
        echo "install_app.sh changed hafah's schemas, functions or types while the shared hafah lock was held"
        return 1
    fi
    echo "install_app.sh skipped, exit 0, no hafah object changed"
}

for s in "$@"; do
    case "$s" in
        shellcheck) step shellcheck run_shellcheck ;;
        sql-registered) step sql-registered sql_registered ;;
        install) step install install ;;
        reinstall) step reinstall reinstall ;;
        install-lock) step install-lock install_lock ;;
        api-smoke) step api-smoke on_clone python3 .aidev/hafah_smoke.py "$out" ;;
        tavern) step tavern on_clone python3 .aidev/hafah_tavern.py "$out" ;;
        rewriter) step rewriter on_clone python3 .aidev/hafah_rewriter_tests.py "$out" ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
