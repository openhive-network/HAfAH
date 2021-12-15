import os
from unittest import TestCase
import json


RESPONSE_FILE_EXT = ".out.json"
PATTERN_FILE_EXT = ".pat.json"
TEST_FILE_EXT = ".tavern.yaml"


def json_pretty_string(json_obj):
  return json.dumps(json_obj, sort_keys=True, indent=2)


def load_pattern(name):
    """ Loads pattern from json file to python object """
    ret = None
    try:
        with open(name, 'r') as f:
            ret = json.load(f)
    except FileNotFoundError:
        pass
    return ret


def save_json(file_name, response_json):
    """ Save response to file """
    with open(file_name, 'a') as f:
      f.write(json_pretty_string(response_json))
      f.write("\n")


def remove_tag(data, tags_to_remove):
    if not isinstance(data, (dict, list)):
        return data
    if isinstance(data, list):
        return [remove_tag(v, tags_to_remove) for v in data]
    else:
        return {k: remove_tag(v, tags_to_remove) for k, v in data.items() if k not in tags_to_remove}


def compare_response_with_pattern(response, *, script_name: str, script_directory: str, ignore_tags: list = None):
    """ This method will compare response with pattern file """
    print()
    print(script_name)
    print(script_directory)
    
    response_file_path = script_directory + '/' + script_name.replace(TEST_FILE_EXT, RESPONSE_FILE_EXT)
    pattern_file_path = script_directory + '/' + script_name.replace(TEST_FILE_EXT, PATTERN_FILE_EXT)

    if os.path.exists(response_file_path):
        os.remove(response_file_path)

    response_json = response.json()
    pattern_json = load_pattern(pattern_file_path)

    if ignore_tags is not None:
        assert isinstance(ignore_tags, list), "ignore_tags should be list of tags"
        response_json = remove_tag(response_json, ignore_tags)
        pattern_json = remove_tag(pattern_json, ignore_tags)

    tc = TestCase()
    tc.maxDiff = None
    try:
        tc.assertDictEqual(pattern_json, response_json)
    except:
        save_json(response_file_path, response_json)
        raise
