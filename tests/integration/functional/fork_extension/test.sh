#!/bin/sh

test_path=$1;

psql -d postgres -a -f  ./create_db.sql;

psql -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};
result=$?;

psql -d postgres -a -f ./drop_db.sql;

if [ ${result} -eq 0 ]
then
  echo "PASSED";
  exit 0;
fi

echo "FAILED";
exit 1;

