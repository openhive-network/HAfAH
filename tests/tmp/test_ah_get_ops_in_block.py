#!/usr/bin/env python3
"""
  Usage: script_name jobs url1 url2 [wdir [last_block [first_block]]]
    Example: script_name 4 http://127.0.0.1:8090 http://127.0.0.1:8091 ./ 5000000 0
    set jobs to 0 if you want use all processors
    if last_block == 0, it is read from url1 (as reference)
"""

from argparse import ArgumentParser
import sys
import simplejson as json
import os
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path


def recurse_browse_for_title(data):
  if isinstance(data, (list, tuple)):
    for val in data:
      if recurse_browse_for_title(val):
        return True
  elif isinstance(data, dict):
    if 'title' in data and 'author' in data and data['author'] == 'kalipo':
      tit = data['title']
      print(f"{'#'*12}, {[(c, ord(c)) for c in tit]}, `{tit}`", flush=True)
      return True
    else:
      for val in data.values():
        if recurse_browse_for_title(val):
          return True
  return False

def hived_call(url, data, *args, **kwargs):
    from requests import post
    result = post(url, json=data)
    return [result.status_code, result.text]

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
  arg_engine.add_argument('-j', dest='jobs', type=int, default=0, help='amount of threads to use, if 0 (default) use all CPUs')
  arg_engine.add_argument('-d', dest='wdir', type=str, default='workdir', help='path where output should be kept (ex. /path/to/workdir)')
  args = arg_engine.parse_args(list(sys.argv[1:]))

  jobs = args.jobs
  url1 = args.ref_node
  url2 = args.test_node
  wdir = Path(args.wdir)
  first_block = args.start
  last_block = args.stop

  if jobs <= 0:
    import multiprocessing
    jobs = multiprocessing.cpu_count()

  assert first_block > 0
  assert last_block > first_block

  create_wdir()

  blocks = last_block - first_block + 1

  if jobs > blocks:
    jobs = blocks

  print("setup:")
  print("  jobs: {}".format(jobs))
  print("  url1: {}".format(url1))
  print("  url2: {}".format(url2))
  print("  wdir: {}".format(wdir))
  print("  block range: {}:{}".format(first_block, last_block))

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


def get_last_block(url, max_tries=10, timeout=0.1):
  request = bytes( json.dumps( {
    "jsonrpc": "2.0",
    "id": 0,
    "method": "database_api.get_dynamic_global_properties",
    "params": {}
    } ), "utf-8" ) + b"\r\n"

  status, response = hived_call(url, data=request, max_tries=max_tries, timeout=timeout)

  if status == False:
    return 0
  try:
    return response["result"]["head_block_number"]
  except:
    return 0


def compare_results(f_block, l_block, url1, url2, max_tries=10, timeout=0.1):
  global wdir

  print( "Compare blocks [{} : {}]".format(f_block, l_block) )

  for i in range(f_block, l_block+1):
    request = {
      "jsonrpc": "2.0",
      "id": i,
      "method": "account_history_api.get_ops_in_block",
      "params": { "block_num": i, "only_virtual": False }
      }

    with ThreadPoolExecutor(max_workers=2) as executor:
    #with ProcessPoolExecutor(max_workers=2) as executor:
      future1 = executor.submit(hived_call, url1, data=request, max_tries=max_tries, timeout=timeout)
      future2 = executor.submit(hived_call, url2, data=request, max_tries=max_tries, timeout=timeout)

    status1, json1 = future1.result()
    status2, json2 = future2.result()
    json1 = json.loads(json1)
    json2 = json.loads(json2)

    if i == 4910595:
      print("REFERENCE: ", end='', flush=True)
      recurse_browse_for_title(json1)

      print("TESTED: ", end='', flush=True)
      recurse_browse_for_title(json2)

    #status1, json1 = hived_call(url1, data=request, max_tries=max_tries, timeout=timeout)
    #status2, json2 = hived_call(url2, data=request, max_tries=max_tries, timeout=timeout)

    if status1 == False or status2 == False or json1 != json2:
      print("Difference @block: {}\n".format(i))

      filename1 = wdir / Path(str(f_block) + "_" + str(l_block) + "_ref.log")
      filename2 = wdir / Path(str(f_block) + "_" + str(l_block) + "_tested.log")

      req = json.dumps(request)
      with filename1.open("w") as file:
        file.write(f'{url1}|{req}' + '\n')
        json.dump(json1, file, indent=2, sort_keys=True, default=vars)

      with filename2.open("w") as file:
        file.write(f'{url2}|{req}' + '\n')
        json.dump(json2, file, indent=2, sort_keys=True, default=vars)

      print( "Compare blocks [{} : {}] break with error".format(f_block, l_block) )
      return False

  print( "Compare blocks [{} : {}] finished".format(f_block, l_block) )
  return True


if __name__ == "__main__":
  main()
