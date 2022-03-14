#! /bin/bash

set -euo pipefail 

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cleanup () {
  echo "Performing cleanup...."
  python_pid=$(pidof 'python3')
  echo "python_pid: $python_pid"
  
  sudo -n kill -INT $python_pid

  echo "Waiting for hafah finish..."
  tail --pid=$python_pid -f /dev/null || true
  echo "hafah finish done."

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


pushd /home/hive/app

{
python3 ./main.py --psql-db-path=${POSTGRES_URL} --port=${HTTP_PORT} "$@"
echo "HafAH process finished execution: $?"
} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
wait $job_pid || true

echo "Exiting docker entrypoint..."

