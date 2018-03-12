#!/bin/bash

EXIT_CODE=0
GROUP_TOTAL=0
GROUP_SKIPPED=0
GROUP_FAILURE=0
JOBS=1
API_TEST_PATH=../../python_scripts/tests/api_tests
BLOCK_SUBPATH=blockchain/block_log
GROUP_TEST_SCRIPT=test_group.sh
STEEMD_CONFIG=config.ini
NODE_ADDRESS=127.0.0.1
TEST_PORT=8090
REF_PORT=8091
TEST_NODE=$NODE_ADDRESS:$TEST_PORT
REF_NODE=$NODE_ADDRESS:$REF_PORT
TEST_NODE_OPT=--webserver-http-endpoint=$TEST_NODE
REF_NODE_OPT=--webserver-http-endpoint=$REF_NODE

function echo(){ builtin echo $(basename $0 .sh): "$@"; }
pushd () { command pushd "$@" > /dev/null; }
popd () { command popd "$@" > /dev/null; }

function print_help_and_quit {
   echo "Usage: path_to_tested_steemd path_to_reference_steemd path_to_test_blockchain_directory path_to_reference_blockchain_directory number_of_blocks_to_replay"
   echo "Example: ~/work/steemit/steem/build/Release/programs/steemd/steemd ~/master/steemit/steem/build/Release/programs/steemd/steemd ~/steemit/steem/work1 ~/steemit/steem/work2 5000000"
   exit $EXIT_CODE
}

function check_steemd_path {
   echo Checking $1...
   if [ -x "$1" ] && file "$1" | grep -q "executable"
   then
      echo OK: $1 is executable file.
   else
      echo FATAL: $1 is not executable file or found! && exit -1
   fi
}

function check_work_path {
   echo Checking $1...
   if [ -e "$1" ] && [ -e "$1/$BLOCK_SUBPATH" ]
   then
      echo OK: $1/$BLOCK_SUBPATH found.
   else
      echo FATAL: $1 not found or $BLOCK_SUBPATH not found in $1! && exit -1
   fi
}

function run_replay {
   echo Running $1 replay of $BLOCK_LIMIT blocks
   $2 --replay --stop-replay-at-block $BLOCK_LIMIT -d $3
   [ $? -ne 0 ] && echo FATAL: steemd failed to replay $BLOCK_LIMIT blocks. && exit -1
}

function copy_config {
   echo Copying ./$STEEMD_CONFIG over $1/$STEEMD_CONFIG
   cp ./$STEEMD_CONFIG $1/$STEEMD_CONFIG
   [ $? -ne 0 ] && echo FATAL: Failed to copy ./$STEEMD_CONFIG over $1/$STEEMD_CONFIG file. && exit -1
}

function check_pid_port {
   echo Checking that steemd with pid $1 listens at $2 port.

   NETSTAT_CMD="netstat -tlpn 2> /dev/null"
   STAGE1=$(eval $NETSTAT_CMD)
   STAGE2=$(echo $STAGE1 | grep -o ":$2 [^ ]* LISTEN $1/steemd")
   ATTEMPT=0

   while [[ -z $STAGE2 ]] && [ $ATTEMPT -lt 3 ]; do
      sleep 1
      STAGE1=$(eval $NETSTAT_CMD)
      STAGE2=$(echo $STAGE1 | grep -o ":$2 [^ ]* LISTEN $1/steemd")
      ((ATTEMPT++))
   done

   if [[ -z $STAGE2 ]]; then
      echo FATAL: Could not find steemd with pid $1 listening at port $2 using $NETSTAT_CMD command.
      echo FATAL: Most probably another steemd instance is running and listens at the port.
      return 1
   else
      return 0
   fi
}

function run_test_group {
   echo Running test group $1
   pushd $1

   if ! [ -x "$GROUP_TEST_SCRIPT" ]; then
      echo Skipping subdirectory $1 due to missing $GROUP_TEST_SCRIPT file.
      ((GROUP_SKIPPED++))
      popd
      return
   fi

   copy_config $TEST_WORK_PATH
   copy_config $REF_WORK_PATH

   run_replay "test instance" $STEEMD_PATH $TEST_WORK_PATH
   run_replay "reference instance" $REF_STEEMD_PATH $REF_WORK_PATH

   echo Running tested steemd to listen
   $STEEMD_PATH $TEST_NODE_OPT -d $TEST_WORK_PATH & TEST_STEEMD_PID=$!
   echo Running reference steemd to listen
   $REF_STEEMD_PATH $REF_NODE_OPT -d $REF_WORK_PATH & REF_STEEMD_PID=$!

   if check_pid_port $TEST_STEEMD_PID $TEST_PORT && check_pid_port $REF_STEEMD_PID $REF_PORT; then
      echo Running ./$GROUP_TEST_SCRIPT $JOBS $NODE_ADDRESS $TEST_PORT $NODE_ADDRESS $REF_PORT $BLOCK_LIMIT
      ./$GROUP_TEST_SCRIPT $JOBS $NODE_ADDRESS $TEST_PORT $NODE_ADDRESS $REF_PORT $BLOCK_LIMIT
      [ $? -ne 0 ] && echo test group $1 FAILED && ((GROUP_FAILURE++)) && EXIT_CODE=-1
   else
      ((GROUP_FAILURE++))
   fi

   kill -s SIGINT $TEST_STEEMD_PID
   kill -s SIGINT $REF_STEEMD_PID
   wait
   popd
}

if [ $# -ne 5 ]
then
   print_help_and_quit
fi

STEEMD_PATH=$1
REF_STEEMD_PATH=$2
TEST_WORK_PATH=$3
REF_WORK_PATH=$4
BLOCK_LIMIT=$5

check_steemd_path $STEEMD_PATH
check_steemd_path $REF_STEEMD_PATH

check_work_path $TEST_WORK_PATH
check_work_path $REF_WORK_PATH

for dir in ./*/
do
    dir=${dir%*/}
    run_test_group ${dir##*/}
    ((GROUP_TOTAL++))
done

echo TOTAL test groups: $GROUP_TOTAL
echo SKIPPED test groups: $GROUP_SKIPPED
echo FAILED test groups: $GROUP_FAILURE

exit $EXIT_CODE
