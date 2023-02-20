#! /bin/bash

set -euo pipefail

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTDIR/haf/scripts"

export LOG_FILE=docker_entrypoint.log
# shellcheck source=../scripts/common.sh
source "$SCRIPTSDIR/common.sh"

export POSTGRES_VERSION=${POSTGRES_VERSION:-14}

cleanup () {
  echo "Performing cleanup...."
  hived_pid=$(pidof 'hived' || echo '') # pidof returns 1 if hived isn't running, which crashes the script 
  echo "Hived pid: $hived_pid"

  jobs -l

  [[ -z "$hived_pid" ]] || sudo -n kill -INT "$hived_pid"

  echo "Waiting for hived finish..."
  [[ -z "$hived_pid" ]] || tail --pid="$hived_pid" -f /dev/null
  echo "Hived finish done."

  postgres_pid=0
  if [ -f "/var/run/postgresql/${POSTGRES_VERSION}-main.pid" ];
  then
    postgres_pid=$(cat "/var/run/postgresql/${POSTGRES_VERSION}-main.pid")
  fi

  sudo -n /etc/init.d/postgresql stop

  echo "Waiting for postgres process: $postgres_pid finish..."
  if [ "$postgres_pid" -ne 0 ];
  then
    tail --pid="$postgres_pid" -f /dev/null || true
  fi

  echo "postgres finish done."

  echo "Cleanup actions done."
}

prepare_pg_hba_file() {
  sudo -En /bin/bash << EOF
  echo -e "${PG_ACCESS}" > "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf.default" >> "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
EOF
}

# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT

echo "Starting the container with user $(whoami)"

prepare_pg_hba_file

if [ ! -d /home/hived/datadir ]
then
  sudo --user=hived -n mkdir -p /home/hived/datadir
fi

# Fix permissions on data and shm directories
sudo -n chown -Rc hived:users /home/hived/datadir
sudo -n chown -Rc hived:users /home/hived/shm_dir

# Be sure those directories exists and have right permissions
sudo --user=hived -n mkdir -p /home/hived/datadir/blockchain
sudo --user=hived -n mkdir -p /home/hived/datadir/postgresql_logs
sudo --user=hived -n mkdir -p /home/hived/datadir/haf_postgresql_conf.d
sudo -n chown -Rc postgres:postgres /home/hived/datadir/postgresql_logs
sudo -n chown -Rc postgres:postgres /home/hived/datadir/haf_postgresql_conf.d

if [ -d "$PGDATA" ]
then
  echo "Attempting to setup postgres instance already containing HAF database..."

  # Fix permissions on Postgres data directory
  sudo -n chown -Rc postgres:postgres "$HAF_DB_STORE"
  sudo -n chown -Rc postgres:postgres "$PGDATA"

  # in case when container is restarted over already existing (and potentially filled) data directory, we need to be sure that docker-internal postgres has deployed HFM extension
  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"
  sudo -n "/usr/share/postgresql/${POSTGRES_VERSION}/extension/hive_fork_manager_update_script_generator.sh" --haf-admin-account=haf_admin --haf-db-name=haf_block_log

  echo "Postgres instance setup completed."
else
  sudo --user=hived -n mkdir -p "$PGDATA"
  sudo --user=hived -n mkdir -p "$HAF_DB_STORE/tablespace"
  sudo -n chown -Rc postgres:postgres "$HAF_DB_STORE"
  sudo -n chown -Rc postgres:postgres "$PGDATA"

  echo "Attempting to setup postgres instance: running initdb..."
 
  # Here is an exception against using /etc/init.d/postgresql script to manage postgres - maybe there is some better way to force initdb using regular script.
  sudo --user=postgres -n PGDATA="$PGDATA" "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb"

  echo "Attempting to setup postgres instance: running setup_postgres.sh..."

  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"

  echo "Postgres instance setup completed."

  ./haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-app-user=haf_app_admin

  sudo -n ./haf/scripts/setup_pghero.sh --database=haf_block_log
fi

cd /home/hived/datadir

# be sure postgres is running
sudo -n /etc/init.d/postgresql start

HIVED_ARGS=()
HIVED_ARGS+=("$@")
export HIVED_ARGS

echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

echo "${BASH_SOURCE[@]}"

{
sudo --user=hived -En /bin/bash << EOF
echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir=/home/hived/datadir --shared-file-dir=/home/hived/shm_dir \
  --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
  ${HIVED_ARGS[@]} 2>&1 | tee -i hived.log
echo "$? Hived process finished execution."
EOF
echo "$? Attempting to stop Postgresql..."

postgres_pid=0
if [ -f "/var/run/postgresql/$POSTGRES_VERSION-main.pid" ];
then
  postgres_pid=$(cat "/var/run/postgresql/$POSTGRES_VERSION-main.pid")
fi

sudo -n /etc/init.d/postgresql stop

echo "Waiting for postgres process: $postgres_pid finish..."
if [ "$postgres_pid" -ne 0 ];
then
  tail --pid="$postgres_pid" -f /dev/null || true
fi

echo "Postgres process: $postgres_pid finished."

} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
wait $job_pid || true

echo "Exiting docker entrypoint..."

