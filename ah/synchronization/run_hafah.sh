#!/bin/bash 

set -e 
set -o pipefail 

if [ ! -d "./.hafah_env" ]
then
  echo "Creating new environment..."
  python3 -mvenv .hafah_env
  source ./.hafah_env/bin/activate
  pip install pip --upgrade
else
  echo "Reusing existing environment..."
  source ./.hafah_env/bin/activate
fi

pip install -r requirements.txt
python3 ./ah-v4.py "$@"

./.hafah_env/bin/deactivate
