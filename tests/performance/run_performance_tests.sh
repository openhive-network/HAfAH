#!/bin/bash

set -e
set -o pipefail

test_scenario_path="$(pwd)/tests/performance/test_scenarios.jmx"
test_result_path=${TEST_RESULT_PATH:-"$(pwd)/tests/performance/result.jtl"}
test_report_dir=${TEST_REPORT_DIR:-"$(pwd)/tests/performance/result_report"}
test_thread_count=${TEST_THREAD_COUNT:-8}
test_loop_count=${TEST_LOOP_COUNT:-60}
backend_port=${BACKEND_PORT:-3000}
backend_host=${BACKEND_HOST:-localhost}


while [ $# -gt 0 ]; do
case "$1" in
    --test-report-dir=*)
    test_report_dir="${1#*=}"
    ;;
    --test-result-path=*)
    test_result_path="${1#*=}"
    ;;
    --test-thread-count=*)
    test_thread_count="${1#*=}"
    ;;
    --test-loop-count=*)
    test_loop_count="${1#*=}"
    ;;
    --backend-port=*)
    backend_port="${1#*=}"
    ;;
    --backend-host=*)
    backend_host="${1#*=}"
    ;;
    -*)
        echo "Unknown option: $1"
        exit 1
        ;;
    *)
        echo "Unknown argument: $1"
        exit 2
        ;;
esac
shift
done

test_summary_report_path="${test_result_path%jtl}xml"


rm -f "$test_result_path"
mkdir -p "${test_result_path%/*}"
rm -rf "$test_report_dir"
mkdir -p "$test_report_dir"
jmeter --nongui --testfile "$test_scenario_path" --logfile "$test_result_path" \
--reportatendofloadtests --reportoutputfolder "$test_report_dir" \
--jmeterproperty backend.port="$backend_port" --jmeterproperty backend.host="$backend_host" \
--jmeterproperty thread.count="$test_thread_count" --jmeterproperty loop.count="$test_loop_count" \
--jmeterproperty summary.report.path="$test_summary_report_path"