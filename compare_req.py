import requests as r
import os
import json
import subprocess as sub
import re

def bool_to_str(param):
    return str(param).lower()


def get_url(port):
    if port == 3000:
        url = "http://localhost:%d" % port
    else:
        url = "http://localhost:%d" % port
    return url


def get_res(url, api_type, method, params_str):
    __headers = headers.copy()
    if is_hafah_new_style and url == po_url:
        if switch_schema:
            for name in re.findall("[a-z_]+.(?=\":)", params_str): params_str = params_str.replace(name, "_%s" %name)
            __headers["Content-Profile"] = "hafah_objects"
        if api_type == "condenser_api":
            __headers["Is-Legacy-Style"] = "TRUE"

        data = params_str
        url = "%s/rpc/%s" %(url, method)
    else:
        params_str = '"params": %s' %params_str
        data = "{%s}" % (", ".join([jsonrpc_str, method_str % (api_type, method), params_str, id_str]))
    print(data)
    return r.post(url=url, data=data, headers=__headers)


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
                print()
                res = get_res(url, api_type, method, 
                    params_str_dict[method] % tuple([list(param.values())[0] for param in params_tuple_dict[method]])
                )
                res_status.append(res.status_code)
                print(res)

                if is_hafah_new_style and url == py_url:
                    try:
                        res = res.json()["result"]
                    except:
                        res = res.json()
                elif is_hafah_new_style and url == po_url:
                    try:
                        res = json.loads(res.json())
                    except:
                        res = res.json()
                elif is_hafah_new_style is False:
                    res = res.json()
                save_res(url, res, method, api_type)
            
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
        "get_ops_in_block": '{"block_num": %s, "only_virtual": %s, "include_reversible": %s}',
        "enum_virtual_ops": '{"block_range_begin": %s, "block_range_end": %s, "operation_begin": %s, "limit": %s, "filter": %s, "include_reversible": %s, "group_by_block": %s}',
        "get_transaction": '{"id": "%s", "include_reversible": %s}',
        "get_account_history": '{"account": "%s", "start": %s, "limit": %s, "operation_filter_low": %s, "operation_filter_high": %s, "include_reversible": %s}'
    }

    params_tuple_dict = {
        "get_ops_in_block": ({"block_num": 3476140}, {"only_virtual": bool_to_str(False)}, {"include_reversible": bool_to_str(False)}),
        "enum_virtual_ops": ({"block_range_begin": 3744644}, {"block_range_end": 3744646}, {"operation_begin": 9844922}, {"limit": 1}, {"filter": 16384}, {"include_reversible": bool_to_str(False)}, {"group_by_block": bool_to_str(False)}),
        "get_transaction": ({"id": "390464f5178defc780b5d1a97cb308edeb27f983"}, {"include_reversible": bool_to_str(True)}),
        "get_account_history": ({"account": "hello"}, {"start": 1000}, {"limit": 1000}, {"operation_filter_low": 512}, {"operation_filter_high": 0}, {"include_reversible": bool_to_str(False)})
    }

    methods = ["get_ops_in_block", "enum_virtual_ops", "get_transaction", "get_account_history"]
    methods = ["get_ops_in_block"]

    #is_hafah_new_style = True
    #switch_schema = False
    is_hafah_new_style = False

    compare_method_responses(methods, params_str_dict, params_tuple_dict)