#! /bin/bash

set -xeuo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cleanup () {
  echo "Performing cleanup...."
  python_pid=$(pidof 'python3' || true)
  if [ ! -z "$python_pid" ]; then
    echo "python_pid: $python_pid"

    sudo -En kill -INT $python_pid

    echo "Waiting for hafah-python finish..."
    tail --pid=$python_pid -f /dev/null || true
    echo "hafah-python finish done."
  fi

  echo "Cleanup actions done."
}

trap cleanup INT QUIT TERM

while [ $# -gt 0 ]; do
  case "$1" in
    --psql-db-path=*)
        POSTGRES_URL="${1#*=}"
        ;;
    --port=*)
        HTTP_PORT="${1#*=}"
        ;;
    esac
    shift
done

pushd /home/hafah_user/app

# credits: https://stackoverflow.com/a/39028690/11738218
RETRIES=72
until psql ${POSTGRES_URL} -c "SELECT 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
  sleep 10
done

./scripts/setup_postgres.sh --postgres-url=${POSTGRES_URL}
./scripts/setup_db.sh --postgres-url=${POSTGRES_URL}

{
echo "Attempting to start HafAH process..."
sudo -Enu hafah_user ./scripts/run_hafah.sh
echo "HafAH process finished execution: $?"
} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
wait $job_pid || true

echo "Exiting docker entrypoint..."

