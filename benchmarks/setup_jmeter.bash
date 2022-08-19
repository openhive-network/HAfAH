#!/bin/bash

set -euo pipefail

WORKDIR=jmeter
JMETER_DOWNLOAD_URL="https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.4.3.zip"
JMETER_POSTGRES_DOWNLOAD_URL="https://jdbc.postgresql.org/download/postgresql-42.3.1.jar"

if [[ -f "$WORKDIR/activate" ]]; then
    echo "using cached jmeter"
    exit 0
fi

echo "creating work directory"
mkdir -p "$WORKDIR"

pushd "$WORKDIR"

echo "downloading jmeter"
wget --quiet "$JMETER_DOWNLOAD_URL" > /dev/null

echo "unzipping jmeter"
unzip -qq apache-*.zip > /dev/null

echo "removing archive and renaming jmeter directory"
rm apache-*.zip
mv apache* apache

    pushd apache
        pushd lib
                echo "downloading postgres driver for jmeter"
                wget --quiet "$JMETER_POSTGRES_DOWNLOAD_URL" > /dev/null
        popd

        export JMETER="$PWD/bin/jmeter"
    popd

    echo "For handy usage, execute following command"
    echo "echo 'export JMETER=$JMETER' >> ~/.bashrc"
    echo "JMETER=$JMETER" > activate

    echo "testing is jmeter properly configured"
    $JMETER --version
popd
