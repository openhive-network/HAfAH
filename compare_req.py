from pickle import FALSE, NONE
import re
import requests as r
import os
import json
from tqdm import tqdm
import subprocess as sub


def bool_to_str(param):
    return str(param).lower()

def get_url(port):
    if port == 3000:
        url = "http://localhost:%d/rpc/home" % port
    else:
        url = "http://localhost:%d" % port
    return url


def send_req(url, api_type, method, params_str):
    data = "{%s}" % (", ".join([jsonrpc_str, method_str % (api_type, method), params_str, id_str]))
    return r.post(url=url, data=data, headers=headers).json()

"""
def send_req(url, api_type, method, params_str):
    if str(py_port) in url:
        data = "{%s}" % (", ".join([jsonrpc_str, method_str % (api_type, method), params_str, id_str]))
    elif str(po_port) in url:
        data = params_str
        url += method
    return r.post(url=url, data=data, headers=headers).json()
"""

def save_res(url, res, method, api_type):
    if str(py_port) in url: version = "py"
    elif str(po_port) in url: version = "pstg"

    f_path = os.path.join(json_dir, "%s_%s_(%s).json" % (version, method, api_type))
    with open(f_path, "w") as f:
        f.write("%s" % json.dumps(res, indent=4, sort_keys=True))


def compare_json(method, api_type):
    py_f = os.path.join(json_dir, "py_%s_(%s).json" %(method, api_type))
    pstg_f = os.path.join(json_dir, "pstg_%s_(%s).json" %(method, api_type))
    p = sub.run('diff "%s" "%s"' %(py_f, pstg_f), shell=True, capture_output=True, text=True)
    print(p.stdout)


def get_ops_in_block(method="get_ops_in_block"):
    block_num = 5
    only_virtual = bool_to_str(True)
    include_reversible = bool_to_str(True)

    api_type = "account_history_api"

    params_str = '"params": {"block_num": %d, "only_virtual": %s, "include_reversible": %s}'
    params_str = params_str % (block_num, only_virtual, include_reversible)
    py_url = get_url(py_port)
    res = send_req(py_url, api_type, method, params_str)
    save_res(py_url, res["result"], method, api_type)

    params_str = '{"_block_num": "%d", "_only_virtual": "%s", "_include_reversible": "%s"}'
    params_str = params_str % (block_num, only_virtual, include_reversible)
    po_url = get_url(po_port)
    res = send_req(po_url, api_type, method, params_str)
    #print(res)
    save_res(po_url, json.loads(res), method, api_type)

    compare_json(method, api_type)


def get_account_history(method="get_account_history"):
    account = "dantheman"
    start = 901
    limit = 100
    operation_filter_low = 0
    operation_filter_high = 5
    include_reversible = bool_to_str(False)

    for api_type in ["account_history_api", "condenser_api"]:
        for port in [8095, 3000]:
            url = get_url(port)

            params_str = '"params": {"account": "%s", "start": %d, "limit": %d, "operation_filter_low": %d, "operation_filter_high": %d, "include_reversible": %s}'
            params_str = params_str % (account, start, limit, operation_filter_low, operation_filter_high, include_reversible)
            res = send_req(url, api_type, method, params_str)
            save_res(url, res, method, api_type)

        compare_json(method, api_type)

def enum_virtual_ops(method="enum_virtual_ops"):
    block_range_begin = 3089794
    block_range_end = 3089794 + 2000
    operation_begin = 10
    limit = 10
    filter = 2
    include_reversible = bool_to_str(False)
    group_by_block = bool_to_str(False)
    
    api_type = "account_history_api"
    if api_type == "account_history_api":
        params_str = '"params": {"block_range_begin": %d, "block_range_end": %d, "operation_begin": %d, "limit": %d, "filter": %d, "include_reversible": %s, "group_by_block": %s}'
        params_str = params_str % (block_range_begin, block_range_end, operation_begin, limit, filter, include_reversible, group_by_block)
        py_url = get_url(py_port)
        res = send_req(py_url, api_type, method, params_str)
        #print(res)
        save_res(py_url, res["result"], method, api_type)

    params_str = '{"_block_range_begin": %d, "_block_range_end": %d, "_operation_begin": %d, "_limit": %d, "_filter": %d, "_include_reversible": %s, "_group_by_block": %s}'
    params_str = params_str % (block_range_begin, block_range_end, operation_begin, limit, filter, include_reversible, group_by_block)
    po_url = get_url(po_port)
    res = send_req(po_url, api_type, method, params_str)
    #print(res)
    save_res(po_url, res, method, api_type)

    compare_json(method, api_type)


def get_transaction(method="get_transaction"):
    id = "390464f5178defc780b5d1a97cb308edeb27f983"
    #id = "bla"
    include_reversible = bool_to_str(True)

    for api_type in ["account_history_api", "condenser_api"]:
        for port in [8095, 3000]:
            url = get_url(port)

            params_str = '"params": {"id": "%s", "include_reversible": %s}'
            params_str = params_str % (id, include_reversible)
            res = send_req(url, api_type, method, params_str)
            save_res(url, res, method, api_type)

        compare_json(method, api_type)

if __name__ == "__main__":
    py_port, po_port = 8095, 3000

    headers = {"Content-Type": "application/json"}
    jsonrpc_str = '"jsonrpc": "2.0"'
    method_str = '"method": "%s.%s"'
    id_str = '"id": "1"'

    json_dir = os.path.join(os.getcwd(), "responses")
    if os.path.isdir(json_dir) is False:
        os.mkdir(json_dir)

    #get_ops_in_block()
    #get_account_history()
    get_transaction()
    #enum_virtual_ops()
