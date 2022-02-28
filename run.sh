#!/bin/bash

set -e
set -o pipefail

echo_success() {
    echo 'SUCCESS: Users and API recreated'
}

create_user() {
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing' -c "call hafah_api.create_api_user();"
}

create_api() {
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $PWD/ah/db/hafah_backend.sql
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $PWD/ah/db/hafah_objects.sql
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $PWD/ah/api/hafah_api.sql
}

start_webserver() {
    postgrest webserver.conf
}

if [ "$1" = "start" ]; then
    start_webserver
elif [ "$1" = "re-api" ]; then
    create_api
    create_user
    echo_success
elif [ "$1" = "re-api-start" ]; then
    create_api
    create_user
    echo_success
    start_webserver
fi;