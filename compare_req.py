import requests as r
import os
import json
from tqdm import tqdm
import subprocess as sub


def bool_to_str(param):
    return str(param).lower()


def get_url(port):
    if port == 3000:
        url = "http://localhost:%d" % port
    else:
        url = "http://localhost:%d" % port
    return url


def get_res(url, api_type, method, params_str):
    data = "{%s}" % (", ".join([jsonrpc_str, method_str % (api_type, method), params_str, id_str]))
    return r.post(url=url, data=data, headers=headers)


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
    if len(p.stdout) > 1:
        print("-----------------------%s-----------------------" %method)
        print(p.stdout)


def compare_status(method, res_status):
    if res_status[0] != res_status[1]:
        print(method, res_status)


def compare_method_responses(methods, params_str_dict, params_tuple_dict):
    for method in methods:
        for api_type in ["account_history_api", "condenser_api"]:
            res_status = []
            for url in [py_url, po_url]:
                res = get_res(
                    url, api_type, method,
                    params_str_dict[method] % tuple([list(param.values())[0] for param in params_tuple_dict[method]]))

                res_status.append(res.status_code)
                save_res(url, res.json(), method, api_type)
            
            compare_status(method, res_status)
            compare_json(method, api_type)


if __name__ == "__main__":
    py_port, po_port = 8095, 3000
    py_url, po_url = get_url(py_port), get_url(po_port)

    headers = {"Content-Type": "application/json"}
    jsonrpc_str = '"jsonrpc": "2.0"'
    method_str = '"method": "%s.%s"'
    id_str = '"id": "1"'

    json_dir = os.path.join(os.getcwd(), "responses")
    if os.path.isdir(json_dir) is False:
        os.mkdir(json_dir)
    
    params_str_dict = {
        "get_ops_in_block": '"params": {"block_num": %s, "only_virtual": %s, "include_reversible": %s}',
        "enum_virtual_ops": '"params": {"block_range_begin": %s, "block_range_end": %s, "operation_begin": %s, "limit": %s, "filter": %s, "include_reversible": %s, "group_by_block": %s}',
        "get_transaction": '"params": {"id": "%s", "include_reversible": %s}',
        "get_account_history": '"params": {"account": "%s", "start": %s, "limit": %s, "operation_filter_low": %s, "operation_filter_high": %s, "include_reversible": %s}'
    }

    params_tuple_dict = {
        "get_ops_in_block": ({"block_num": 5}, {"only_virtual": bool_to_str(True)}, {"include_reversible": bool_to_str(True)}),
        "enum_virtual_ops": ({"block_range_begin": 3089794}, {"block_range_end": 3089796}, {"operation_begin": 0}, {"limit": 1000}, {"filter": 0}, {"include_reversible": bool_to_str(True)}, {"group_by_block": bool_to_str(True)}),
        "get_transaction": ({"id": "390464f5178defc780b5d1a97cb308edeb27f983"}, {"include_reversible": bool_to_str(True)}),
        "get_account_history": ({"account": "dantheman"}, {"start": 0}, {"limit": 10}, {"operation_filter_low": 0}, {"operation_filter_high": 0}, {"include_reversible": bool_to_str(True)})
    }

    methods = ["get_ops_in_block", "enum_virtual_ops", "get_transaction", "get_account_history"]

    compare_method_responses(methods, params_str_dict, params_tuple_dict)