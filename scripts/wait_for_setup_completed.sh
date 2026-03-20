#! /bin/bash
set -euo pipefail

# Currently unused, leaving in case this changes later
# SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

DATABASE_URL=""
LIMIT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --postgres-url=*)
        DATABASE_URL_RAW="${1#*=}"
        DATABASE_URL=$(bash -c "echo ${DATABASE_URL_RAW}")
        ;;
    --timeout=*)
        LIMIT="${1#*=}"
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        exit 2
        ;;
    esac
    shift
done


wait_for_postgres() {
  local time_limit=$1
  echo "Waiting for postgres hosted by container at the URL: ${DATABASE_URL}, timeout: ${time_limit} s."

  timeout "$time_limit" bash -c "until psql \"${DATABASE_URL}\" -c 'SELECT 1;' ; do sleep 3 ; done"

  echo "Postgres pointed by ${DATABASE_URL} at the URL is ready."
}

wait_for_app_setup() {
  local time_limit=$1

  echo "Waiting for application setup at the URL: ${DATABASE_URL}, timeout: ${time_limit}."

  set +e

  local db_url="${DATABASE_URL}"
  export SETUP_CHECK_DB_URL="${db_url}"

  timeout -v "${time_limit}" bash -c '
    retry=0
    while true; do
      status=$(psql -qAt "${SETUP_CHECK_DB_URL}" -c "SELECT COALESCE((SELECT hafah_backend.is_setup_completed()), false);" 2>/dev/null)
      if [ "${status}" = "t" ]; then
        break
      fi
      retry=$((retry+1))
      echo "${retry} Retrying a wait for application setup at the URL: ${SETUP_CHECK_DB_URL}."
      sleep 1
    done
  '

  retcode=$?
  set -e

  if [ ${retcode} -eq 0 ]; then
    echo "Application is ready."
  fi

  return ${retcode}
}

wait_for_postgres $((LIMIT/2))
wait_for_app_setup $((LIMIT/2))
