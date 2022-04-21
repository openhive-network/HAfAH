#! /bin/bash

set -euo pipefail 

POSTGREST_VERSION=9.0.0

postgrest=postgrest-v${POSTGREST_VERSION}-linux-static-x64.tar.xz
wget https://github.com/PostgREST/postgrest/releases/download/v${POSTGREST_VERSION}/postgrest-v${POSTGREST_VERSION}-linux-static-x64.tar.xz

sudo -n tar xvf postgrest-v${POSTGREST_VERSION}-linux-static-x64.tar.xz -C '/usr/local/bin'

rm postgrest-v${POSTGREST_VERSION}-linux-static-x64.tar.xz


