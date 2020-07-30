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

def compare_response_with_pattern(response, method=None, directory=None):
  """ This method will compare response with pattern file """
  response_json = response.json()
  error = response_json.get("error", None)
  result = response_json.get("result", None)
  assert error is None, "Error detected in response: {}".format(error["message"])
  assert result is not None, "Error detected in response: result is null, json object was expected"

  import jsondiff
  pattern = load_pattern(directory + "/" + method + PATTERN_FILE_EXT)
  pattern_resp_diff = jsondiff.diff(pattern, result)
  if pattern_resp_diff:
    fname = directory + "/" + method + DIFF_FILE_EXT
    response_fname = directory + "/" + method + RESPONSE_FILE_EXT
    save_diff(fname, pattern_resp_diff)
    save_response(response_fname, result)
    msg = "Differences detected between response and pattern. Diff saved to {}\n\nDiff:\n{}".format(fname, pattern_resp_diff)
    raise PatternDiffException(msg)
