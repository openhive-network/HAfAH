#!/bin/bash

set -euo pipefail

WORKDIR=m2u
M2U_URL="https://github.com/tguzik/m2u.git"

echo "creating work directory"
mkdir -p "$WORKDIR"


pushd "$WORKDIR"

    echo "downloading m2u"
    git clone "$M2U_URL" --single-branch -b master .

    echo "configuring m2u"
    mvn 2>&1 >/dev/null

    echo "M2U='java -jar $PWD/target/m2u.jar'" > activate

popd
