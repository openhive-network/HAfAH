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

install_dependancies() {
    install_postgrest
    install_plpython
    install_jmeter
}

install_postgrest() {
    wget https://github.com/PostgREST/postgrest/releases/download/v$postgrest_v/postgrest-v$postgrest_v-linux-static-x64.tar.xz

    POSTGREST=$(find . -name 'postgrest*')
    tar xJf $POSTGREST
    sudo mv 'postgrest' '/usr/local/bin/postgrest'
    rm $POSTGREST
}

install_plpython() {
    sudo apt-get update -y
    sudo apt-get -y install python3 postgresql-plpython3-12
}

install_jmeter() {
    sudo apt-get update -y
    sudo apt-get install openjdk-8-jdk -y

    wget "https://downloads.apache.org//jmeter/binaries/apache-jmeter-${jmeter_v}.zip"

    jmeter_src="apache-jmeter-${jmeter_v}"
    unzip "${jmeter_src}.zip"
    rm "${jmeter_src}.zip"
    sudo mv $jmeter_src "/usr/local/src/${jmeter_src}"

    jmeter="jmeter-${jmeter_v}"
    touch $jmeter
    echo '#!/usr/bin/env bash' >> $jmeter
    echo '' >> $jmeter
    echo "cd '/usr/local/src/apache-jmeter-${jmeter_v}/bin'" >> $jmeter
    echo './jmeter $@' >> $jmeter
    sudo chmod +x $jmeter
    sudo mv $jmeter "/usr/local/bin/${jmeter}"
}

test_performance() {
    if [ $# -eq 0 ]; then
        PORT=3000
    else
        PORT=$1
    fi
    
    ./tests/performance/run_perf_tests.bash /usr/local/bin/jmeter-$jmeter_v $PWD/tests/performance postgrest $PORT
}

postgrest_v=9.0.0
jmeter_v=5.4.3

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
elif [ "$1" =  "install-dependancies" ]; then
    install_dependancies
elif [ "$1" =  "install-postgrest" ]; then
    install_postgrest
elif [ "$1" =  "install-plpython" ]; then
    install_plpython
elif [ "$1" =  "install-jmeter" ]; then
    install_jmeter
elif [ "$1" =  "test-performance" ]; then
    test_performance $2
else
    echo "job not found"
    exit 1
fi;