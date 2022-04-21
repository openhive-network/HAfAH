#! /bin/bash

set -euo pipefail 

ROOT_DIR="${1}"
USE_POSTGREST=${2}

chmod a+x ${ROOT_DIR}/docker_entrypoint.sh
cd ${ROOT_DIR}/app
if [ ${USE_POSTGREST} -eq 0 ]; then
  pip3 install --no-cache-dir -r requirements.txt
  mv ./scripts/run_hafah_python.sh ./scripts/run_hafah.sh
else
  ./scripts/setup_postgrest.sh
  mv ./scripts/run_hafah_postgrest.sh ./scripts/run_hafah.sh
fi

chmod a+x ./scripts/run_hafah.sh
