#! /bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

DATABASE_URL=""
LIMIT=300

while [ $# -gt 0 ]; do
  case "$1" in
    --postgres-url=*)
        DATABASE_URL_RAW="${1#*=}"
        DATABASE_URL=$(bash -c "echo ${DATABASE_URL_RAW}")
        ;;
    --timeout=*)
        LIMIT="${1#*=}"
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        exit 2
        ;;
    esac
    shift
done


wait_for_postgres() {
  local time_limit=$1
  echo "Waiting for postgres hosted by container at the URL: ${DATABASE_URL}, timeout: ${time_limit} s."

  timeout $time_limit bash -c "until psql \"${DATABASE_URL}\" -c 'SELECT 1;' ; do sleep 3 ; done"

  echo "Postgres pointed by ${DATABASE_URL} at the URL is ready."
}

wait_for_app_setup() {
  local time_limit=$1

  psql -q "${DATABASE_URL}" -v ON_ERROR_STOP=on -f- <<EOF
CREATE OR REPLACE FUNCTION public.app_setup_helper()
RETURNS BOOLEAN
IMMUTABLE
LANGUAGE PLPGSQL
AS
\$\$
BEGIN
	RETURN hafah_python.is_setup_completed();
EXCEPTION WHEN OTHERS THEN
	RETURN FALSE;
END
\$\$;
EOF

  set +e

  timeout -v "${time_limit}" bash <<EOF
    echo "Waiting for application setup at the URL: ${DATABASE_URL}, timeout: ${time_limit}."
    retry=0
    status=\$(psql -qAt ${DATABASE_URL} -c 'SELECT public.app_setup_helper();')

    until [ "\${status}" == "t" ] ; do
      retry=\$((retry+1))
      echo "\${retry} Retrying a wait for application setup at the URL: ${DATABASE_URL}.";
      sleep 1 ;
      status=\$(psql -qAt ${DATABASE_URL} -c 'SELECT public.app_setup_helper();')
    done
EOF

  retcode=$?
  psql "${DATABASE_URL}" -q -v ON_ERROR_STOP=on -c 'DROP FUNCTION IF EXISTS public.app_setup_helper;'
  set -e

  if [ ${retcode} -eq 0 ];
  then
    echo "Application is ready."
  fi

  return ${retcode}
}

wait_for_postgres $((${LIMIT}/2))
wait_for_app_setup $((${LIMIT}/2))
