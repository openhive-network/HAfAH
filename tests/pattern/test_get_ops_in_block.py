import git
from pathlib import Path
import requests
import sys
import threading
from jsonrpcclient import parse, request
import json

git_repo = git.Repo('.', search_parent_directories=True)
git_root = git_repo.git.rev_parse("--show-toplevel")
sys.path.append(git_root)

from ah.server.serve import run_server

from expected_get_ops_in_block import request_list, response_list


def test_get_ops_in_block():
    psql = 'postgresql:///haf_block_log'
    port = 6543
    port2 = 6544
    endpoint = f'http://127.0.0.1:{port}'
    endpoint2 = f'http://127.0.0.1:{port2}'
    log_responses = False
    sql_src_path = git_root + "/ah/synchronization/queries/ah_schema_functions.sql"
    print(sql_src_path)

    threading.Thread(target=run_server, args=(psql, port, log_responses, sql_src_path), daemon=True).start()
    f1 = open('response_list.py', 'a')
    f2 = open('response_list_legacy.py', 'a')

    import time
    time.sleep(10)

    for expected_request, expected_response_text in zip(request_list, response_list):
        response = requests.post(endpoint, data=expected_request)
        response2 = requests.post(endpoint2, data=expected_request)
        
        f1.write(repr(str(response.text)))
        f1.write(',\n')
        f2.write(repr(str(response2.text)))
        f2.write(',\n')

    f1.close()
    f2.close()
