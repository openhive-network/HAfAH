import requests as r
import os
import json
import subprocess as sub


def bool_to_str(param):
    return str(param).lower()


def send_req(url, method, params_str):
    if str(py_port) in url:
        data = "{%s}" % (", ".join([jsonrpc_str, method_str % method, params_str, id_str % method]))
    elif str(po_port) in url:
        data = params_str
        url += method
    return r.post(url=url, data=data, headers=headers).json()


def save_res(url, res, method):
    if str(py_port) in url: version = "py"
    elif str(po_port) in url: version = "pstg"

    f_path = os.path.join(json_dir, "%s_%s.json" % (method, version))
    with open(f_path, "w") as f:
        f.write("%s" % json.dumps(res, indent=4, sort_keys=True))


def compare_json(method):
    py_f = os.path.join(json_dir, "%s_py.json" %method)
    pstg_f = os.path.join(json_dir, "%s_pstg.json" %method)
    p = sub.run('diff "%s" "%s"' %(py_f, pstg_f), shell=True, capture_output=True, text=True)
    print(p.stdout)


def get_ops_in_block(method="get_ops_in_block"):
    block_num = 0
    only_virtual = bool_to_str(True)
    include_reversible = bool_to_str(True)
    include_op_id = bool_to_str(False)

    params_str = '"params": {"block_num": %d, "only_virtual": %s, "include_reversible": %s}'
    params_str = params_str % (block_num, only_virtual, include_reversible)
    res = send_req(py_url, method, params_str)
    save_res(py_url, res["result"], method)

    params_str = '{"_block_num": "%d", "_only_virtual": "%s", "_include_op_id": "%s", "_include_reversible": "%s"}'
    params_str = params_str % (block_num, only_virtual, include_op_id, include_reversible)
    res = send_req(po_url, method, params_str)
    #print(res)
    save_res(po_url, json.loads(res), method)

    compare_json(method)


def get_account_history(method="get_account_history"):
    _filter = 10
    account = "dantheman"
    start = 5000
    limit = 5000000
    include_reversible = bool_to_str(True)

    params_str = '"params": {"filter": %d, "account": "%s", "start": %d, "limit": %d, "include_reversible": %s}'
    params_str = params_str % (
        _filter, account, start, limit, include_reversible)
    res = send_req(py_url, method, params_str)
    save_res(py_url, res, method)


def enum_virtual_ops(method="enum_virtual_ops"):
    _filter = 0
    block_range_begin = 0
    block_range_end = 5000000
    operation_begin = 10
    limit = 10
    include_reversible = bool_to_str(True)
    group_by_block = bool_to_str(True)

    params_str = '"params": {"filter": %d, "block_range_begin": %d, "block_range_end": %d, "operation_begin": %d, "limit": %d, "include_reversible": %s, "group_by_block": %s}'
    params_str = params_str % (_filter, block_range_begin, block_range_end,
                               operation_begin, limit, include_reversible, group_by_block)
    res = send_req(py_url, method, params_str)
    save_res(py_url, res, method)


def get_transaction(method="get_transaction"):
    id = "390464f5178defc780b5d1a97cb308edeb27f983"
    include_reversible = bool_to_str(True)

    params_str = '"params": {"id": "%s", "include_reversible": %s}'
    params_str = params_str % (id, include_reversible)
    res = send_req(py_url, method, params_str)
    save_res(py_url, res, method)


if __name__ == "__main__":
    py_port = 8095
    py_url = "http://localhost:%d" % py_port

    po_port = 3000
    po_url = "http://localhost:%d/rpc/" % po_port

    headers = {"Content-Type": "application/json"}

    jsonrpc_str = '"jsonrpc": "2.0"'
    method_str = '"method": "account_history_api.%s"'
    id_str = '"id": "${__threadNum}/${__counter(TRUE)}/%s"'

    json_dir = os.path.join(os.getcwd(), "responses")
    if os.path.isdir(json_dir) is False:
        os.mkdir(json_dir)

    get_ops_in_block()
    # get_account_history()
    # get_transaction()
    # enum_virtual_ops()
