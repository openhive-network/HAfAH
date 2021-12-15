import git
from pathlib import Path
import json
import requests
import random
import sys
import threading
from jsonrpcclient import parse, request

git_repo = git.Repo('.', search_parent_directories=True)
git_root = git_repo.git.rev_parse("--show-toplevel")
sys.path.append(git_root)

from ah.server.serve import run_server

jsonrpc_query = '''
{{
	"jsonrpc": "2.0",
	"method": "account_history_api.get_ops_in_block",
	"params": {{}}
		"block_num" : {}
	}},
	"id": 2
}}
'''

def test_get_transaction():
    return
    psql = 'postgresql:///haf_block_log'
    port = 6543
    log_responses = False
    sql_src_path = git_root + "/ah/synchronization/queries/ah_schema_functions.sql"
    t = threading.Thread(target=run_server, args=(psql, port, log_responses, sql_src_path))
    t.daemon = True
    t.start()


    random.seed(10, version=2)
    for i in range(10_000):
        block_num = random.randint(1, 1_000_000)
        print(f'for block number {block_num}')
        json_string = jsonrpc_query.format(block_num)

        try:
            response = requests.post(f'http://127.0.0.1:{port}', json=json.loads(json_string))
            print(response.status_code)
            print(response.text)
        except:
            print('couldnt connect')

