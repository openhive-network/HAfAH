import os
import csv
from difflib import SequenceMatcher
from time import perf_counter as perf
from typing import overload

class PatternDiffException(Exception):
  pass

class NoResultException(Exception):
  pass

def get_overlap(s1, s2):
    s = SequenceMatcher(None, s1, s2)
    pos_a, pos_b, size = s.find_longest_match(0, len(s1), 0, len(s2)) 
    return s1[pos_a:pos_a+size] if pos_b == 0 else ""

def json_pretty_string(json_obj):
  from json import dumps
  return dumps(json_obj, sort_keys=True, indent=2)

def save_json(file_name, response_json):
  """ Save response to file """
  with open(file_name, 'w') as f:
    f.write(json_pretty_string(response_json))
    f.write("\n")

def save_raw(file_name, msg):
  """ Save lack of response to file """
  with open(file_name, 'w') as f:
    f.write(msg)

RESPONSE_FILE_EXT = ".out.json"
PATTERN_FILE_EXT = ".pat.json"
def load_pattern(name):
  """ Loads pattern from json file to python object """
  from json import load
  ret = {}
  with open(name, 'r') as f:
    ret = load(f)
  return ret

def remove_tag(data, tags_to_remove):
  if not isinstance(data, (dict, list)):
    return data
  if isinstance(data, list):
    return [remove_tag(v, tags_to_remove) for v in data]
  return {k: remove_tag(v, tags_to_remove) for k, v in data.items() if k not in tags_to_remove}

def get_time(test_id):
  file_name = os.getenv("HIVEMIND_BENCHMARKS_IDS_FILE", None)
  if file_name is not None:
    with open(file_name, "r") as f:
      reader = csv.reader(f)
      for row in reader:
        if row[0] == test_id:
          return float(row[1])
  return 0.

def compare_response_with_pattern(response, method=None, directory=None, ignore_tags=None, error_response=False, benchmark_time_threshold=None):
  """ This method will compare response with pattern file """
  response_fname = directory + "/" + method + RESPONSE_FILE_EXT
  test_dir = os.getenv("TAVERN_DIR", "")
  overlap = get_overlap(test_dir, response_fname)
  response_fname = response_fname.replace(overlap, "")
  
  if os.path.exists(response_fname):
    os.remove(response_fname)

  response_json = response.json()
  if ignore_tags is not None:
    assert isinstance(ignore_tags, list), "ignore_tags should be list of tags"
    response_json = remove_tag(response_json, ignore_tags)
  error = response_json.get("error", None)
  result = response_json.get("result", None)

  # disable coparison with pattern on demand
  # and save 
  if bool(os.getenv('TAVERN_DISABLE_COMPARATOR', False)):
    if error is not None:
      save_json(response_fname, result)
    test_id = response_json.get("id", None)
    print(test_id)
    if test_id is not None:
      with open("benchmark.csv", 'a') as benchmark_file:
        writer = csv.writer(benchmark_file)
        writer.writerow([directory + "/" + method, perf() - get_time(test_id), int(response.headers.get("Content-Length", 0)), benchmark_time_threshold])
    return

  if error is not None and not error_response:
    msg = "Error detected in response: {}".format(error["message"])
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)
  if error is None and error_response:
    msg = "Error expected but got result: {}".format(result)
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)

  if error_response:
    result = error
  if result is None:
    msg = "Error detected in response: result is null, json object was expected"
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)

  import deepdiff
  pattern = load_pattern(directory + "/" + method + PATTERN_FILE_EXT)
  if ignore_tags is not None:
    pattern = remove_tag(pattern, ignore_tags)
  pattern_resp_diff = deepdiff.DeepDiff(pattern, result)
  if pattern_resp_diff:
    save_json(response_fname, result)
    msg = "Differences detected between response and pattern."
    raise PatternDiffException(msg)

def has_valid_response(response, method=None, directory=None, error_response=False, response_fname=None, benchmark_time_threshold=None):
  import os
  if not response_fname:
    response_fname = directory + "/" + method + RESPONSE_FILE_EXT

  test_dir = os.getenv("TAVERN_DIR", "")
  overlap = get_overlap(test_dir, response_fname)
  response_fname = response_fname.replace(overlap, "")
  response_fname = test_dir + "/" + response_fname
  
  if os.path.exists(response_fname):
    os.remove(response_fname)

  response_json = response.json()
  error = response_json.get("error", None)
  result = response_json.get("result", None)

  if error_response:
    correct_response = error
  else:
    correct_response = result

  # disable coparison with pattern on demand
  # and save 
  if bool(os.getenv('TAVERN_DISABLE_COMPARATOR', False)):
    test_id = response_json.get("id", None)
    if error is not None:
      save_json(response_fname, response_json)
    print(test_id)
    if test_id is not None:
      with open("benchmark.csv", 'a') as benchmark_file:
        writer = csv.writer(benchmark_file)
        writer.writerow([directory + "/" + method, perf() - get_time(test_id), int(response.headers.get("Content-Length", 0)), benchmark_time_threshold])
    return

  save_json(response_fname, response_json)
  if correct_response is None:
    msg = "Error detected in response: result is null, json object was expected"
    raise NoResultException(msg)

