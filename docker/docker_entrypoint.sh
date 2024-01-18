#! /bin/bash
set -euo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

job_pid=0
HAFAH_EXIT_CODE=0

cleanup () {
  local postgrest_pid=0
  echo "Performing cleanup...."
  if [[ ${job_pid} -ne 0 ]]; then
    postgrest_pid=$(pidof 'postgrest' || true)
    echo "HAfAH JOB pid: $job_pid, HAFAH process pid: ${postgrest_pid}"
    sudo -En kill -INT $postgrest_pid || true

    echo "Waiting for hafah finish..."
    tail --pid="${postgrest_pid}" -f /dev/null || true
    echo "HAfAH finish done."
  fi

  echo "Cleanup actions done, exiting with status: ${HAFAH_EXIT_CODE}"

  exit ${HAFAH_EXIT_CODE}
}

# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT

print_help () {
cat <<EOF
  Usage: $0 [install_app|uninstall_app] [OPTION[=VALUE]]...

  Allows to perform application install/uninstall or then start it for regular usage.
  OPTIONS:
    --port=NUMBER       HTTP port to be used by HAfAH (default: ${HTTP_PORT})
    --psql-db-path=URL
    --postgres-url=URL  Allows to specify a PostgreSQL URL to access HAF database. It should point to haf_admin role for install/uninstall steps and hafah_user to regular
                        HAfAH service processing
EOF
}

DO_INSTALL=0
DO_UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --psql-db-path=*)
        export POSTGRES_URL="${1#*=}"
        ;;
    --postgres-url=*)
        export POSTGRES_URL="${1#*=}"
        ;;
    --port=*)
        export HTTP_PORT="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;

    install_app)
      DO_INSTALL=1
      ;;
    uninstall_app)
      DO_UNINSTALL=1
      ;;
    *)
      echo "Unknown subcommand specified, defaulting to application service start"
      ;;
    esac
    shift
done

pushd /home/hafah_user/app

# credits: https://stackoverflow.com/a/39028690/11738218
RETRIES=12
until psql ${POSTGRES_URL} -c "SELECT 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Waiting for postgres server: ${POSTGRES_URL}, $((RETRIES--)) remaining attempts..."
  sleep 10
done

if [ ${DO_INSTALL} -eq 1 ]; then
  "${SCRIPTDIR}/app/scripts/setup_postgres.sh" --postgres-url="${POSTGRES_URL}"
  "${SCRIPTDIR}/app/scripts/install_app.sh" --postgres-url="${POSTGRES_URL}"
  exit $?
fi

if [ ${DO_UNINSTALL} -eq 1 ]; then
  "${SCRIPTDIR}/app/scripts/uninstall_app.sh" --postgres-url="${POSTGRES_URL}"
  exit $?
fi

{
# Start ignoring errors from this point to avoid immediate script termination on error
set +e

sudo -Enu hafah_user "${SCRIPTDIR}/app/scripts/run_hafah_postgrest.sh"
HAFAH_EXIT_CODE=$?

set -e

if [ $HAFAH_EXIT_CODE -eq 130 ];
then
  echo "Ignoring SIGINT exit code: $HAFAH_EXIT_CODE."
  HAFAH_EXIT_CODE=0 #ignore exitcode caught by handling SIGINT
fi

echo "HafAH process finished execution: ${HAFAH_EXIT_CODE}"
} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
wait $job_pid || true

echo "Exiting docker entrypoint ${HAFAH_EXIT_CODE}..."

