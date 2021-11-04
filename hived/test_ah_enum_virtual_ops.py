#!/usr/bin/env python3
"""
  Usage: __name__ jobs url1 url2 [working_dir [accounts_file]]
    Example: script_name 4 http://127.0.0.1:8090 http://127.0.0.1:8091 [get_account_history [accounts]]
    set jobs to 0 if you want use all processors
    url1 is reference url for list_accounts
"""
import sys
import json
import os
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures import Future
from concurrent.futures import wait
from jsonsocket import JSONSocket
from jsonsocket import universal_call as hived_call
from list_account import list_accounts
from pathlib import Path
import deepdiff


wdir = Path()
errors = 0


def future_end_cb(future):
  global errors
  if future.result() == False:
    errors += 1


def main():
  global wdir
  global errors

  arg_engine = ArgumentParser()
  arg_engine.add_argument('--ref', dest='ref_node', type=str, help='address to reference node (ex. http://127.0.0.1:8091)')
  arg_engine.add_argument('--test', dest='test_node', type=str, help='address to tested node (ex. http://127.0.0.1:8095)')
  arg_engine.add_argument('--start', dest='start', type=int, help='block range begin')
  arg_engine.add_argument('--stop', dest='stop', type=int, help='block range end')
  arg_engine.add_argument('-j', dest='jobs', type=int, default=4, help='amount of threads to use')
  arg_engine.add_argument('-d', dest='wdir', type=str, default='workdir', help='path where output should be kept (ex. /path/to/workdir)')
  args = arg_engine.parse_args(list(sys.argv[1:]))

  jobs = args.jobs
  url1 = args.ref_node
  url2 = args.test_node
  wdir = Path(args.wdir)
  first_block = args.start
  last_block = args.stop

  print( "setup:" )
  print( "  jobs: {}".format(jobs) )
  print( "  url1: {}".format(url1) )
  print( "  url2: {}".format(url2) )
  print( "  wdir: {}".format(wdir) )
  print( f"  testing range: [{first_block} : {last_block}]" )

  create_wdir()


  blocks = last_block - first_block + 1

  if jobs > 1:
    blocks_per_job = blocks // jobs

    with ProcessPoolExecutor(max_workers=jobs) as executor:
      for i in range(jobs-1):
        future = executor.submit(compare_results, first_block, (first_block + blocks_per_job - 1), url1, url2)
        future.add_done_callback(future_end_cb)
        first_block = first_block + blocks_per_job
      future = executor.submit(compare_results, first_block, last_block, url1, url2)
      future.add_done_callback(future_end_cb)
  else:
    errors = (compare_results(first_block, last_block, url1, url2) == False)

  exit( errors )


def create_wdir():
  global wdir

  if wdir.exists():
    if wdir.is_file():
      os.remove(wdir)

  if wdir.exists() == False:
    wdir.mkdir(parents=True)


def compare_results(begin, end, url1, url2, max_tries=10, timeout=0.1):
  success = True
  print("Compare operations: [{}..{}]".format(begin, end))

  for bn in range(begin, end):
    if enum_virtual_ops(url1, url2, bn, max_tries, timeout) == False:
      success = False; break

  print("Compare operations: [{}..{}] {}".format(begin, end, "finished" if success else "break with error" ))
  return success


def enum_virtual_ops(url1, url2, bn : int, max_tries=10, timeout=0.1):
  global wdir
  start = 0

  if True:
    request = {
      "jsonrpc":"2.0",
      "method":"account_history_api.enum_virtual_ops",
      "params":{
        "block_range_begin":bn,
        "block_range_end":bn+1,
        "include_reversible":True,
        "start": start
      },
      "id":1
    }

    with ThreadPoolExecutor(max_workers=2) as executor:
      future1 = executor.submit(hived_call, url1, data=request, max_tries=max_tries, timeout=timeout)
      future2 = executor.submit(hived_call, url2, data=request, max_tries=max_tries, timeout=timeout)

    status1, json1 = future1.result()
    status2, json2 = future2.result()

    json1 = json.loads(json1)
    json2 = json.loads(json2)

    if status1 == False or status2 == False or json1 != json2:
      bn_str = str(bn)
      print(f"Comparison failed for block: {bn};")

      filename1 = wdir / (bn_str + "_ref.json")
      filename2 = wdir / (bn_str + "_tested.json")
      filename3 = wdir / (bn_str + "_diff.json")
      try:    file1 = filename1.open("w")
      except: print("Cannot open file:", filename1); return False
      try:    file2 = filename2.open("w")
      except: print("Cannot open file:", filename2); return False
      # try:    file3 = filename3.open("w")
      # except: print("Cannot open file:", filename3); return False

      file1.write("{} response:\n".format(url1))
      json.dump(json1, file1, indent=2, sort_keys=True, default=vars)
      file1.close()
      file2.write("{} response:\n".format(url2))
      json.dump(json2, file2, indent=2, sort_keys=True, default=vars)
      file2.close()
      return False
      file3.write("Differences:\n")
      json_diff = deepdiff.DeepDiff(json1, json2)
      json.dump(json_diff, file3, indent=2, sort_keys=True, default=vars)
      file3.close()
      return False

    start = json1['result']['next_operation_begin']

  return True


if __name__ == "__main__":
  main()
