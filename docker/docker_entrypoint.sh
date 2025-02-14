#! /bin/bash
set -euo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

job_pid=0
HAFAH_EXIT_CODE=0
HTTP_PORT=${HTTP_PORT:-3000}
POSTGRES_URL=${POSTGRES_URL:-}
SWAGGER_URL=${POSTGRES_URL:-"{hafah-host}"}

# shellcheck disable=SC2317
cleanup () {
  local postgrest_pid=0
  echo "Performing cleanup...."
  if [[ ${job_pid} -ne 0 ]]; then
    postgrest_pid=$(pidof 'postgrest' || true)
    echo "HAfAH JOB pid: $job_pid, HAFAH process pid: ${postgrest_pid}"
    sudo -En kill -INT "$postgrest_pid" || true

    echo "Waiting for hafah finish..."
    tail --pid="${postgrest_pid}" -f /dev/null || true
    echo "HAfAH finish done."
  fi

  echo "Cleanup actions done, exiting with status: ${HAFAH_EXIT_CODE}"

  exit "${HAFAH_EXIT_CODE}"
}

# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT

print_help () {
cat <<EOF
  Usage: $0 [install_app|uninstall_app|run|help] [OPTION[=VALUE]]...

  Depending on the command passed as the first argument installs, uninstalls or runs HAfAH
  OPTIONS:
    --port=NUMBER       HTTP port to be used by HAfAH (needed for running, otherwise ignored, default: ${HTTP_PORT})
    --psql-db-path=URL  Alias for --psql-db-path.
    --postgres-url=URL  PostgreSQL URL to access HAF database. It should point to haf_admin role for install/uninstall steps and hafah_user to regular
                        HAfAH service processing
    --swagger-url=URL   Swagger URL (needed for installation, otherwise ignored, default: {hafah-host})
    --help|-h|-?        Ignore the command and print help
EOF
}

wait_for_database() {
  # credits: https://stackoverflow.com/a/39028690/11738218
  RETRIES=12
  until psql "${POSTGRES_URL}" -c "SELECT 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "Waiting for PostgreSQL server to become available: ${POSTGRES_URL}, $((RETRIES--)) remaining attempts..."
    sleep 10
  done
}

run() {
  wait_for_database
  # HAF restarts its database during startup, so let's wait for a bit more
  sleep 10
  wait_for_database

  # Tempfile for HAfAH's exit code.
  # Needed because HAfAH runs in a subshell.
  # See also https://www.shellcheck.net/wiki/SC2031
  HAFAH_EXIT_CODE_FILE=$(mktemp)

  {
  # Start ignoring errors from this point to avoid immediate script termination on error
  set +e

  sudo -Enu hafah_user "${SCRIPTDIR}/app/scripts/run_hafah_postgrest.sh"
  EXIT_CODE=$?

  set -e

  if [ $EXIT_CODE -eq 130 ];
  then
    echo "Ignoring SIGINT exit code: $EXIT_CODE."
    EXIT_CODE=0 #ignore exitcode caught by handling SIGINT
  fi

  echo "$EXIT_CODE" > "$HAFAH_EXIT_CODE_FILE"
  echo "HAfAH process finished execution: ${EXIT_CODE}"
  } &

  job_pid=$!

  jobs -l

  echo "waiting for job finish: $job_pid."
  wait $job_pid || true

  HAFAH_EXIT_CODE=$(cat "$HAFAH_EXIT_CODE_FILE")
  echo "Exiting docker entrypoint ${HAFAH_EXIT_CODE}..."
  exit "${HAFAH_EXIT_CODE}"
}

install() {
  wait_for_database
  # HAF restarts its database during startup, so let's wait for a bit more
  sleep 10
  wait_for_database

  "${SCRIPTDIR}/app/scripts/setup_postgres.sh" --postgres-url="${POSTGRES_URL}"
  "${SCRIPTDIR}/app/scripts/install_app.sh" --postgres-url="${POSTGRES_URL}" --swagger-url="${SWAGGER_URL}"

  exit $?
}

uninstall() {
  wait_for_database
  # HAF restarts its database during startup, so let's wait for a bit more
  sleep 10
  wait_for_database

  "${SCRIPTDIR}/app/scripts/uninstall_app.sh" --postgres-url="${POSTGRES_URL}"

  exit $?
}

echo "Script parameters: $*"

COMMAND="${1:-}"

if [[ -z "${COMMAND}" || "${COMMAND::2}" == "--" ]]; then
# If there's no command specified, assume the command is 'run'
# and only options are provided
  COMMAND="run"
else
# If the command is specified remove it from the parameters
# to leave only options
  shift
fi

echo -e "Command: ${COMMAND}\nOptions: $*"

pushd /home/hafah_user/app

while [ $# -gt 0 ]; do
  case "$1" in
    --psql-db-path=*)
      POSTGRES_URL_RAW="${1#*=}"
      # Declare and export separately: https://www.shellcheck.net/wiki/SC2155
      POSTGRES_URL=$(bash -c "echo ${POSTGRES_URL_RAW}")
      export POSTGRES_URL
      ;;
    --postgres-url=*)
      POSTGRES_URL_RAW="${1#*=}"
      # Declare and export separately: https://www.shellcheck.net/wiki/SC2155
      POSTGRES_URL=$(bash -c "echo ${POSTGRES_URL_RAW}")
      export POSTGRES_URL
      ;;
    --port=*)
      export HTTP_PORT="${1#*=}"
      ;;
    --swagger-url=*)  
      export SWAGGER_URL="${1#*=}"
      ;;
    --help|-h|-\?)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option specified, exiting..."
      print_help
      exit 1
      ;;
    esac
    shift
done

case "$COMMAND" in
  install_app)
    echo "Beginning app installation..."
    install
    ;;
  uninstall_app)
    echo "Beginning app uninstallation..."
    uninstall
    ;;
  run)
    echo "Running app..."
    run
    ;;
  help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown command specified, exiting..."
    print_help
    exit 1
    ;;
esac
