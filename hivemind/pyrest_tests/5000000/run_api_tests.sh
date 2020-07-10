#!/bin/bash

EXIT_CODE=0
COMPARATOR=''

if [[ $# -ne 2 ]]; then 
    echo "Usage: run_api_benchmarks target_address comparator(equal/contain)"
    exit 1
fi

if [ $2 == 'equal' ]
then
   COMPARATOR='comparator_equal'
elif [ $2 == 'contain' ]
then
   COMPARATOR='comparator_contain'
else
   echo FATAL: $2 is not a valid comparator! && exit -1
fi

echo COMPARATOR: $COMPARATOR
echo "Running API tests\n"
pyresttest $1 ./basic_smoketest.yaml
[ $? -ne 0 ] && echo FATAL: hivemind not running? && exit -1

pyresttest $1 ./bridge/bridge_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./condenser_api/condenser_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./database_api/database_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./follow_api/follow_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./hive_api/hive_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1

pyresttest $1 ./tags_api/tags_api_test.yaml --import_extensions='validator_ex;'$COMPARATOR
[ $? -ne 0 ] && EXIT_CODE=-1
echo "Done!\n"

exit $EXIT_CODE
