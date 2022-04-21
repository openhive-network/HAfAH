#! /bin/bash

set -euo pipefail 

#Helper script to run HAfAH python from docker.
 
python3 ./main.py --psql-db-path=${POSTGRES_URL} --port=${HTTP_PORT} "$@"

