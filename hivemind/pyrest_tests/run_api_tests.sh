#!/bin/bash

EXIT_CODE=0
COMPARATOR=''

if [[ $# -ne 3 ]]; then 
    echo "Usage: run_api_tests.sh target_address tests_directory comparator(equal/contain)"
    echo "Example: ./run_api_tests.sh https://api.hive.blog full_sync contain"
    exit 1
fi

if [ $3 == 'equal' ]
then
   COMPARATOR='comparator_equal'
elif [ $3 == 'contain' ]
then
   COMPARATOR='comparator_contain'
else
   echo FATAL: $3 is not a valid comparator! && exit -1
fi

echo COMPARATOR: $COMPARATOR
echo "Running API tests"
pyresttest $1 ./basic_smoketest.yaml
[ $? -ne 0 ] && echo FATAL: hivemind not running? && exit -1

echo ./$2/bridge/bridge_api_test.yaml
pyresttest $1 ./$2/bridge/bridge_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./$2/condenser_api/condenser_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./$2/database_api/database_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./$2/follow_api/follow_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./$2/hive_api/hive_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./$2/tags_api/tags_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1
echo "Done!"

exit $EXIT_CODE
