import csv
import os
from time import perf_counter as perf

class NoResultException(Exception):
  pass

def json_pretty_string(json_obj):
  from json import dumps
  return dumps(json_obj, sort_keys=True, indent=2)

def save_json(file_name, response_json):
  """ Save response to file """
  with open(file_name, 'w') as f:
    f.write(json_pretty_string(response_json))
    f.write("\n")

RESPONSE_FILE_EXT = ".out.json"

def get_time(test_id):
  file_name = os.getenv("HIVEMIND_BENCHMARKS_IDS_FILE", None)
  if file_name is not None:
    with open(file_name, "r") as f:
      reader = csv.reader(f)
      for row in reader:
        print(row[0], "    ", test_id)
        if row[0] == test_id:
          return float(row[1])
  return 0.

def compare_response_with_pattern(response, method=None, directory=None, ignore_tags=None, error_response=False):
    # as its file for full sync, all pattern test should be only checked if has valid response, not pattern
    has_valid_response(response, method, directory, error_response, "../tavern/" + directory + "/" + method + RESPONSE_FILE_EXT)

def has_valid_response(response, method=None, directory=None, error_response=False, response_fname=None):
  import os
  if not response_fname:
    response_fname = directory + "/" + method + RESPONSE_FILE_EXT

  if os.path.exists(response_fname):
    os.remove(response_fname)

  response_json = response.json()
  if error_response:
    correct_response = response_json.get("error", None)
  else:
    correct_response = response_json.get("result", None)

  # disable coparison with pattern on demand
  # and save 
  if bool(os.getenv('TAVERN_DISABLE_COMPARATOR', False)):
    test_id = response_json.get("id", None)
    print(test_id)
    if test_id is not None:
      with open("benchmark.csv", 'a') as benchmark_file:
        writer = csv.writer(benchmark_file)
        writer.writerow([directory + "/" + method, perf() - get_time(test_id)])
    return

  save_json(response_fname, response_json)
  if correct_response is None:
    msg = "Error detected in response: result is null, json object was expected"
    raise NoResultException(msg)
