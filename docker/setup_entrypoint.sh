#! /bin/sh
set -e
cd /hafah/scripts
./setup_postgres.sh --postgres-url=${POSTGRES_URL}
./install_app.sh --postgres-url=${POSTGRES_URL}
