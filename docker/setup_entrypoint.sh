#! /bin/sh
set -e
cd /hafah/scripts

if [ "$1" = "install_app" ]; then
  ./setup_postgres.sh --postgres-url=${POSTGRES_URL}
  ./install_app.sh --postgres-url=${POSTGRES_URL}
elif [ "$1" = "uninstall_app" ]; then
  ./uninstall_app.sh --postgres-url=${POSTGRES_URL}
else
  echo "usage: $0 install_app|uninstall_app"
  exit 1
fi

