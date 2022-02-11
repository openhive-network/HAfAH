#!/usr/bin/env python3
"""
  Usage: __name__ jobs url1 url2 [working_dir [accounts_file]]
    Example: script_name 4 http://127.0.0.1:8090 http://127.0.0.1:8091 [get_account_history [accounts]]
    set jobs to 0 if you want use all processors
    url1 is reference url for list_accounts
"""
from argparse import ArgumentParser
import sys
import json
import os
import shutil
import locale
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
  arg_engine.add_argument('-f', dest='in_file', type=str, default=None, help='path to file with accounts to test')
  arg_engine.add_argument('-j', dest='jobs', type=int, default=0, help='amount of threads to use, if 0 (default) use all CPUs')
  arg_engine.add_argument('-d', dest='wdir', type=str, default='workdir', help='path where output should be kept (ex. /path/to/workdir)')
  args = arg_engine.parse_args(list(sys.argv[1:]))

  jobs = args.jobs
  url1 = args.ref_node
  url2 = args.test_node
  wdir = Path(args.wdir)
  accounts_file = args.in_file

  if jobs <= 0:
    import multiprocessing
    jobs = multiprocessing.cpu_count()

  if accounts_file is not None:
    try:
      with open(accounts_file, "rt") as file:
        accounts = [x.strip('\n') for x in file.readlines()]
    except:
      exit("Cannot open file: " + accounts_file)
  else:
    accounts = list_accounts(url1)

  length = len(accounts)

  if length == 0:
    exit("There are no any account!")

  create_wdir()

  print( str(length) + " accounts" )

  if jobs > length:
    jobs = length

  print( "setup:" )
  print( "  jobs: {}".format(jobs) )
  print( "  url1: {}".format(url1) )
  print( "  url2: {}".format(url2) )
  print( "  wdir: {}".format(wdir) )
  print( "  accounts_file: {}".format(accounts_file) )

  if jobs > 1:
    first = 0
    last = length
    accounts_per_job = length // jobs

    with ProcessPoolExecutor(max_workers=jobs) as executor:
      for i in range(jobs-1):
        future = executor.submit(compare_results, url1, url2, accounts[first : first+accounts_per_job])
        future.add_done_callback(future_end_cb)
        first = first + accounts_per_job
      future = executor.submit(compare_results, url1, url2, accounts[first : last])
      future.add_done_callback(future_end_cb)
  else:
    errors = (compare_results(url1, url2, accounts) == False)

  exit( errors )


def create_wdir():
  global wdir

  if wdir.exists():
    if wdir.is_file():
      os.remove(wdir)

  if wdir.exists() == False:
    wdir.mkdir(parents=True)


def compare_results(url1, url2, accounts, max_tries=10, timeout=0.1):
  success = True
  print("Compare accounts: [{}..{}]".format(accounts[0], accounts[-1]))

  for account in accounts:
    if get_account_history(url1, url2, account, max_tries, timeout) == False:
      success = False; break

  print("Compare accounts: [{}..{}] {}".format(accounts[0], accounts[-1], "finished" if success else "break with error" ))
  return success


def get_account_history(url1, url2, account, max_tries=10, timeout=0.1):
  global wdir
  START = -1
  HARD_LIMIT = 1000
  LIMIT = HARD_LIMIT

  while True:
    request = {
      "jsonrpc": "2.0",
      "id": 0,
      "method": "account_history_api.get_account_history",
      "params": { "account": account, "start": START, "limit": LIMIT }
      }

    with ThreadPoolExecutor(max_workers=2) as executor:
      future1 = executor.submit(hived_call, url1, data=request, max_tries=max_tries, timeout=timeout)
      future2 = executor.submit(hived_call, url2, data=request, max_tries=max_tries, timeout=timeout)

    status1, json1 = future1.result()
    status2, json2 = future2.result()
    json1 = json.loads(json1)
    json2 = json.loads(json2)
    #status1, json1 = hived_call(url1, data=request, max_tries=max_tries, timeout=timeout)
    #status2, json2 = hived_call(url2, data=request, max_tries=max_tries, timeout=timeout)

    if status1 == False or status2 == False or json1 != json2:
      print("Comparison failed for account: {}; start: {}; limit: {}".format(account, START, LIMIT))

      filename1 = wdir / (account.strip() + "_ref.json")
      filename2 = wdir / (account.strip() + "_tested.json")

      req = json.dumps(request)
      with filename1.open("w") as file:
        file.write(f'{url1}|{req}' + '\n')
        json.dump(json1, file, indent=2, sort_keys=True, default=vars)

      with filename2.open("w") as file:
        file.write(f'{url2}|{req}' + '\n')
        json.dump(json2, file, indent=2, sort_keys=True, default=vars)

      return False

    history = json1["result"]["history"]
    last = history[0][0] if len(history) else 0

    if last == 0 or last == 1:
      break

    last -= 1
    START = last
    LIMIT = last if last < HARD_LIMIT else HARD_LIMIT
  # while True

  return True


if __name__ == "__main__":
  main()
