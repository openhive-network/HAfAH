#!/bin/bash

set -e
set -o pipefail

echo_success() {
    echo 'SUCCESS: Users and API recreated'
}

create_user() {
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing' -c "call hafah_backend.create_api_user();"
}

create_api() {
    postgrest_dir=$PWD/postgrest
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $postgrest_dir/hafah_backend.sql
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $postgrest_dir/hafah_objects.sql
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -f $postgrest_dir/hafah_api.sql
}

start_webserver() {
    postgrest postgrest.conf
}

install_dependancies() {
    install_postgrest
    install_plpython
    install_jmeter
}

install_postgrest() {
    sudo apt-get update -y
    sudo apt-get install wget -y

    postgrest=postgrest-v$postgrest_v-linux-static-x64.tar.xz
    wget https://github.com/PostgREST/postgrest/releases/download/v$postgrest_v/$postgrest

    sudo tar xvf $postgrest -C '/usr/local/bin'
    rm $postgrest
}

install_plpython() {
    sudo apt-get update -y
    sudo apt-get -y install python3 postgresql-plpython3-12
}

install_jmeter() {
    sudo apt-get update -y
    sudo apt-get install openjdk-8-jdk -y
    sudo apt-get install unzip

    wget "https://downloads.apache.org//jmeter/binaries/apache-jmeter-${jmeter_v}.zip"

    jmeter_src="apache-jmeter-${jmeter_v}"
    sudo unzip "${jmeter_src}.zip" -d '/usr/local/src'
    rm "${jmeter_src}.zip"

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
    ./tests/performance/run_perf_tests.bash /usr/local/bin/jmeter-$jmeter_v $PWD/tests/performance $@
}

test_patterns() {
    port=$1
    cd $PWD/haf/hive
    
    ./tests/api_tests/run_tests.sh $port $PWD
}

postgrest_v=9.0.0
jmeter_v=5.4.3

if [ "$1" = "start" ]; then
    start_webserver
elif [ "$1" = "re-all" ]; then
    create_api
    create_user
    echo_success
elif [ "$1" = "re-all-start" ]; then
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
    test_performance ${@:2}
elif [ "$1" =  "test-patterns" ]; then
    test_patterns ${@:2}
else
    echo "job not found"
    exit 1
fi;
