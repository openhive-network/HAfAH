import os
import csv
from difflib import SequenceMatcher
from time import perf_counter as perf
import deepdiff
import re

class PatternDiffException(Exception):
  pass

class NoResultException(Exception):
  pass

# set of predefined "tags" that can be used in tests to ignore specific elements
# of result json when comparing with pattern - only one per test (ignore_tags should
# be a string denoting predefined situation), exclusive with regular (not predefined)
# tags (in normal case ignore_tags must be a list of tag specifiers)
predefined_ignore_tags = {
  '<bridge post>' : re.compile(r"root\['post_id'\]"),
  '<bridge posts>' : re.compile(r"root\[\d+\]\['post_id'\]"),
  '<bridge discussion>' : re.compile(r"root\[.+\]\['post_id'\]"),
  '<bridge community>' : re.compile(r"root\['id'\]"),
  '<bridge communities>' : re.compile(r"root\[\d+\]\['id'\]"),
  '<bridge profile>' : re.compile(r"root\['id'\]"),
  '<condenser posts>' : re.compile(r"root\[\d+\]\['post_id'\]"),
  '<condenser content>' : re.compile(r"root\['id'\]"), # condenser_api.get_content
  '<condenser replies>' : re.compile(r"root\[\d+\]\['id'\]"), # condenser_api.get_content_replies
  '<condenser blog>' : re.compile(r"root\[\d+\]\['comment'\]\['post_id'\]"), # condenser_api.get_blog
  '<condenser state>' : re.compile(r"root\['content'\]\[.+\]\['post_id'\]"), # condenser_api.get_state
  '<database posts>' : re.compile(r"root\['comments'\]\[\d+\]\['id'\]"),
  '<database votes>' : re.compile(r"root\['votes'\]\[\d+\]\['id'\]"),
  '<follow blog>' : re.compile(r"root\[\d+\]\['comment'\]\['post_id'\]"), # follow_api.get_blog
  '<tags posts>' : re.compile(r"root\[\d+\]\['post_id'\]"),
  '<tags post>' : re.compile(r"root\['post_id'\]") # tags_api.get_discussion
}

def get_overlap(s1, s2):
    s = SequenceMatcher(None, s1, s2)
    pos_a, pos_b, size = s.find_longest_match(0, len(s1), 0, len(s2)) 
    return s1[pos_a:pos_a+size] if pos_b == 0 else ""

def json_pretty_string(json_obj):
  from json import dumps
  return dumps(json_obj, sort_keys=True, indent=2)

def save_json(file_name, response_json):
  """ Save response to file """
  with open(file_name, 'a') as f:
    f.write(json_pretty_string(response_json))
    f.write("\n")

def save_raw(file_name, msg):
  """ Save lack of response to file """
  with open(file_name, 'w') as f:
    f.write(msg)

RESPONSE_FILE_EXT = ".out.json"
PATTERN_FILE_EXT = ".pat.json"
TEST_FILE_EXT = ".tavern.yaml"

def load_pattern(name):
  """ Loads pattern from json file to python object """
  from json import load
  ret = None
  try:
    with open(name, 'r') as f:
      ret = load(f)
  except FileNotFoundError as ex:
    pass
  return ret

def remove_tag(data, tags_to_remove):
  if not isinstance(data, (dict, list)):
    return data
  if isinstance(data, list):
    return [remove_tag(v, tags_to_remove) for v in data]
  return {k: remove_tag(v, tags_to_remove) for k, v in data.items() if k not in tags_to_remove}

def get_time(test_id):
  from json import loads
  file_name = os.getenv("HIVEMIND_BENCHMARKS_IDS_FILE", None)
  if file_name is not None:
    with open(file_name, "r") as f:
      reader = csv.reader(f)
      for row in reader:
        if row[0] == test_id:
          return (float(row[1]), row[2])
  return (0., "{}")

def compare_response_with_pattern(response, method=None, directory=None, ignore_tags=None, error_response=False, benchmark_time_threshold=None, allow_null_response=False):
  """ This method will compare response with pattern file """
  test_fname, _ = os.getenv('PYTEST_CURRENT_TEST').split("::")
  
  test_dir = os.getenv("TAVERN_DIR", "")
  overlap = get_overlap(test_dir, test_fname)
  test_fname = test_dir + "/" + test_fname.replace(overlap, "")
  test_fname = test_fname.replace(TEST_FILE_EXT, "")
  
  response_fname = test_fname + RESPONSE_FILE_EXT
  pattern_fname = test_fname + PATTERN_FILE_EXT
  
  tavern_disable_comparator = bool(os.getenv('TAVERN_DISABLE_COMPARATOR', False))

  if os.path.exists(response_fname) and not tavern_disable_comparator:
    os.remove(response_fname)

  response_json = response.json()
  error = response_json.get("error", None)
  if os.getenv("IS_DIRECT_CALL_HAFAH", "").lower() == "true":
    result = response_json
  else:
    result = response_json.get("result", None)

  exclude_regex_path = None
  if isinstance(ignore_tags, str):
    assert ignore_tags in predefined_ignore_tags, "Unknown predefined meta-tag specified in ignore_tags"
    exclude_regex_path = predefined_ignore_tags[ignore_tags]
    ignore_tags = None
  if ignore_tags is not None:
    assert isinstance(ignore_tags, list), "ignore_tags should be list of tags"

  # disable comparison with pattern on demand and save 
  if tavern_disable_comparator:
    if error is not None:
      save_json(response_fname, error)
    test_id = response_json.get("id", None)
    if test_id is not None:
      with open("benchmark.csv", 'a') as benchmark_file:
        writer = csv.writer(benchmark_file)
        test_time, test_params = get_time(test_id)
        writer.writerow([test_fname, perf() - test_time, int(response.headers.get("Content-Length", 0)), benchmark_time_threshold, test_params])
    return

  if error is not None and not error_response:
    msg = "Error detected in response - see {} for details".format(response_fname)
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)
  if error is None and error_response:
    msg = "Error expected but got result - see {} for details".format(response_fname)
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)

  if error_response:
    result = error
  if result is None and not allow_null_response:
    msg = "Error detected in response: result is null, json object was expected"
    save_json(response_fname, response_json)
    raise PatternDiffException(msg)

  pattern = load_pattern(pattern_fname)
  if pattern is None:
    if result is None:
      return
    save_json(response_fname, result)
    msg = "Pattern is missing."
    raise PatternDiffException(msg)
  if ignore_tags is not None:
    pattern = remove_tag(pattern, ignore_tags)
    result = remove_tag(result, ignore_tags)
  if exclude_regex_path is not None:
    pattern_resp_diff = deepdiff.DeepDiff(pattern, result, exclude_regex_paths=[exclude_regex_path])
  else:
    pattern_resp_diff = deepdiff.DeepDiff(pattern, result)
  if pattern_resp_diff:
    save_json(response_fname, result)
    msg = "Differences detected between response and pattern."
    raise PatternDiffException(msg)

def has_valid_response(response, method=None, directory=None, error_response=False, response_fname=None, benchmark_time_threshold=None):
  test_fname, _ = os.getenv('PYTEST_CURRENT_TEST').split("::")
  
  test_dir = os.getenv("TAVERN_DIR", "")
  overlap = get_overlap(test_dir, test_fname)
  test_fname = test_dir + "/" + test_fname.replace(overlap, "")
  test_fname = test_fname.replace(TEST_FILE_EXT, "")
  
  response_fname = test_fname + RESPONSE_FILE_EXT

  tavern_disable_comparator = bool(os.getenv('TAVERN_DISABLE_COMPARATOR', False))
  
  if os.path.exists(response_fname) and not tavern_disable_comparator:
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
  if tavern_disable_comparator:
    test_id = response_json.get("id", None)
    if error is not None:
      save_json(response_fname, error)
    if test_id is not None:
      with open("benchmark.csv", 'a') as benchmark_file:
        writer = csv.writer(benchmark_file)
        test_time, test_params = get_time(test_id)
        writer.writerow([test_fname, perf() - test_time, int(response.headers.get("Content-Length", 0)), benchmark_time_threshold, test_params])
    return

  save_json(response_fname, response_json)
  if correct_response is None:
    msg = "Error detected in response: result is null, json object was expected"
    raise NoResultException(msg)
