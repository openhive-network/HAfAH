class PatternDiffException(Exception):
  pass

def json_pretty_string(json_obj):
  from json import dumps
  return dumps(json_obj, sort_keys=True, indent=2)

def save_diff(name, diff):
  """ Save diff to a file """
  with open(name, 'w') as f:
    f.write(str(diff))
    f.write("\n")

def save_response(file_name, response_json):
  """ Save response to file """
  with open(file_name, 'w') as f:
    f.writelines(json_pretty_string(response_json))

def save_no_response(file_name, msg):
  """ Save lack of response to file """
  with open(file_name, 'w') as f:
    f.write(msg)

RESPONSE_FILE_EXT = ".out.json"
PATTERN_FILE_EXT = ".pat.json"
DIFF_FILE_EXT = ".diff.json"
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

def compare_response_with_pattern(response, method=None, directory=None, ignore_tags=None):
  """ This method will compare response with pattern file """
  import os
  fname = directory + "/" + method + DIFF_FILE_EXT
  response_fname = directory + "/" + method + RESPONSE_FILE_EXT
  if os.path.exists(fname):
    os.remove(fname)
  if os.path.exists(response_fname):
    os.remove(response_fname)

  response_json = response.json()
  if ignore_tags is not None:
    assert isinstance(ignore_tags, list), "ingore_tags should be list of tags"
    response_json = remove_tag(response_json, ignore_tags)
  error = response_json.get("error", None)
  result = response_json.get("result", None)
  if error is not None:
    msg = "Error detected in response: {}".format(error["message"])
    save_no_response(response_fname, msg)
    raise PatternDiffException(msg)
  if result is None:
    msg = "Error detected in response: result is null, json object was expected"
    save_no_response(response_fname, msg)
    raise PatternDiffException(msg)

  import jsondiff
  pattern = load_pattern(directory + "/" + method + PATTERN_FILE_EXT)
  if ignore_tags is not None:
    pattern = remove_tag(pattern, ignore_tags)
  pattern_resp_diff = jsondiff.diff(pattern, result)
  if pattern_resp_diff:
    save_diff(fname, pattern_resp_diff)
    save_response(response_fname, result)
    msg = "Differences detected between response and pattern. Diff saved to {}\n\nDiff:\n{}".format(fname, pattern_resp_diff)
    raise PatternDiffException(msg)
