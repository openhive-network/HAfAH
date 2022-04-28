#!/bin/bash

set -euo pipefail

ARCHIVE=artiffacts.zip
TEST_PORT=$( expr $HTTP_PORT + 1 )

function relpath() {
    FROM=$1
    TO=$2
    python3 -c "from os.path import relpath; print(relpath('$TO', '$FROM'))"
}

pushd /home/hafah_user

    # perform tests
    source jmeter/activate
    if [[ "$USE_POSTGREST" -eq "0" ]]
    then
        python3 ./app/tests/performance_test.py     \
            -c perf_5M_heavy.csv                    \
            --postgres $POSTGRES_URL                \
            -d $PERFORMANCE_DIR                     \
            -p $TEST_PORT                           \
            -j $JMETER                              \
            --explicit-python
    else
        HTTP_PORT=$TEST_PORT /home/hafah_user/docker_entrypoint.sh &
        python3 ./app/tests/performance_test.py     \
            -c perf_5M_heavy.csv                    \
            -d $PERFORMANCE_DIR                     \
            -p $TEST_PORT                           \
            -j $JMETER                              \
            --no-launch
    fi;

    # prepare junit xml report
    source m2u/activate
    $M2U --input $PERFORMANCE_DIR/raw_jmeter_report.xml --output $PERFORMANCE_DIR/jmeter_junit_report.xml

    # compress artiffacts
    zip -r $ARCHIVE $( relpath $PWD $PERFORMANCE_DIR )

    # move archive to shared directory
    mv $ARCHIVE "/builds/$ARCHIVE"

    # start mock server, to let CI knows that service is up and running
    python3 -m http.server $HTTP_PORT

popd
