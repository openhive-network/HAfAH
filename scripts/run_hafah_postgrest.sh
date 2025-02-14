#! /bin/bash
set -euo pipefail

# set both variables at rather at runtime than docker build time, to allow changing their values in subsequent docker container starts.
export PGRST_DB_URI=${POSTGRES_URL}
export PGRST_SERVER_PORT=${HTTP_PORT}

echo "Attempting to start HAfAH process using a ${POSTGRES_URL} as database connection and listening on: ${HTTP_PORT} port..."
#Helper script to run HAfAH PostgREST from docker.
/usr/local/bin/postgrest
