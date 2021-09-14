#!/usr/bin/python3
from sys import argv
from json import dumps, dump

def process_file(filename) -> dict:
    threads_with_records = {}

    with open(filename, 'r') as file:
        for i, line in enumerate(file):
            if i == 0:
                continue
            elements = line.split(',')
            if len(elements) > 5:
                time = elements[1]
                thread_name = elements[5]
                if not thread_name in threads_with_records:
                    threads_with_records[thread_name] = [int(time)]
                else:
                    threads_with_records[thread_name].append(int(time))

    merged_threads = {}

    for key, values in threads_with_records.items():
        mkey = key.split(' ')[0]
        if not mkey in merged_threads:
            merged_threads[mkey] = values
        else:
            for i, value in enumerate(values):
                merged_threads[mkey][i] = (merged_threads[mkey][i] + value) / 2.0

    return merged_threads


def generate_data(endpoint, data):
    data = data.split(';')
    data = {"bn1": data[0], "bn2": data[1], "acc": data[2], "trx": data[3]}
    if endpoint == 'enum_virtual_ops':
        return {
            "jsonrpc": "2.0",
            "method": "account_history_api.enum_virtual_ops",
            "params": {
                "block_range_begin": int(data["bn1"]),
                "block_range_end": int(data["bn2"]),
                "include_reversible": True,
                "group_by_block": False,
                "operation_begin": 0,
                "limit": 1000
            },
            "id": 1
        }
    elif endpoint == 'get_transaction':
        return {
            "jsonrpc": 2.0,
            "method": "account_history_api.get_transaction",
            "params": {
                "id": data["trx"],
                "include_reversible": True,
            },
            "id": 1
        }
    elif endpoint == 'get_ops_in_block':
        return {
            "jsonrpc": "2.0",
            "method": "account_history_api.get_ops_in_block",
            "params": {
                "block_num": int(data["bn1"]),
                "only_virtual": True,
                "include_reversible": True
            },
            "id": 1
        }
    elif endpoint == 'get_account_history':
        return {
            "jsonrpc": "2.0",
            "method": "account_history_api.get_account_history",
            "params": {
                "account": data["acc"],
                "limit": 1000,
                "start": -1,
                "operation_filter_low": 0,
                "operation_filter_high": 0,
                "include_reversible": True
            },
            "id": 1
        }
    else:
        assert False, f"unknown endpoint: {endpoint}"

def generate_sql(endpoint, data):
    data = data.split(';')
    data = {"bn1": data[0], "bn2": data[1], "acc": data[2], "trx": data[3]}
    if endpoint == 'enum_virtual_ops':
        return f"SELECT * FROM enum_virtual_ops( NULL ::INT[] , {data['bn1']}, {data['bn2']}, 0, 1000, true ) ORDER BY _operation_id"
    elif endpoint == 'get_transaction':
        return f"SELECT * FROM get_transaction( decode('{data['trx']}', 'hex'), true )" # in actual code, sqlalchemy prepares it to proper form without decode
    elif endpoint == 'get_ops_in_block':
        return f"SELECT * FROM get_ops_in_block( {data['bn1']},  true, true )"
    elif endpoint == 'get_account_history':
        return f"SELECT * FROM ah_get_account_history( NULL, '{data['acc']}', 0, 1000, true )"
    else:
        assert False, f"unknown endpoint: {endpoint}"


def compare_files(csv_path, file_1, *args) -> dict:
    csv_data = []
    with open(csv_path, 'r') as file:
        for line in file:
            if len(line) > 0:
                csv_data.append(line.strip('\n'))


    stats_1 = process_file(file_1)

    comprasion = {}
    for key, values in stats_1.items():
        comprasion[key] = []
        for i, value in enumerate(values):
            csv_item = csv_data[(i+1) % len(csv_data)]
            comprasion[key].append([dumps(generate_data(key, csv_item)), generate_sql(key, csv_item), str(value)])

    for filename in args:
        stats = process_file(filename)
        for key, values in stats.items():
            for i, value in enumerate(values):
                comprasion[key][i].append(str(value))

    return comprasion


with open('parsed.csv', 'w') as file:
    comprasion = compare_files(*argv[1:])
    with open('parsed.json', 'w') as jj:
        dump(comprasion, jj)

    file.write("sample_id|body|sql")
    for i in range(2,len(argv)):
        file.write(f'|{argv[i]}')
    file.write('\n')

    counter = 0
    for key, values in comprasion.items():
        for value in values:
            if len(value) == len(argv):
                file.write(f'{counter}|{"|".join(value)}' + '\n')
                counter += 1
            else:
                break 


    # dump(compare_files('result.jtl', 'result.jtl'), file)
