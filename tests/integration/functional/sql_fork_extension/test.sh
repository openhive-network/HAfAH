#!/bin/sh

extension_path=$1
test_path=$2;

psql -d postgres -a -f  ./create_db.sql;

# here add extension sql scripts (order may be important)
psql -d psql_tools_test_db -a -f  ${extension_path}/data_schema.sql
psql -d psql_tools_test_db -a -f  ${extension_path}/context.sql
psql -d psql_tools_test_db -a -f  ${extension_path}/register_table.sql
psql -d psql_tools_test_db -a -f  ${extension_path}/back_from_fork.sql

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

