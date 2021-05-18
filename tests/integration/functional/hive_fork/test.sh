#!/bin/sh

extension_path=$1
test_path=$2;

psql -d postgres -a -f  ./create_db.sql;

psql -d psql_tools_test_db -v ON_ERROR_STOP=on -c 'CREATE EXTENSION hive_fork'
if [ $? -ne 0 ]
then
  echo "FAILED. Cannot create extension"
  exit 1;
fi

psql -d psql_tools_test_db -a -v ON_ERROR_STOP=on -f  ${test_path};
result=$?;

# psql -d postgres -a -f ./drop_db.sql;

if [ ${result} -eq 0 ]
then
  echo "PASSED";
  exit 0;
fi

echo "FAILED";
exit 1;

