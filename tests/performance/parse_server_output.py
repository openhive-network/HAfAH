#!/usr/bin/python3

from sys import argv
from typing import Dict, Tuple, Union

PATH = argv[1]
OUTPUT_PATH = argv[2]
OUTPUT : Dict[str, Dict[int, Tuple[float, float]]] = { "enum_virtual_ops": dict() }

def is_sql_record(endpoint) -> bool:
	return endpoint == 'SQL'

def is_handling_record(endpoint) -> bool:
	return endpoint == 'process_request'

def avg(val1 : float, val2 : float) -> float:
	if val1 is None:
		return val2
	elif val2 is None:
		return val1

	return (val1 + val2) / 2.0

with open(PATH, 'rt') as file:
	current_endpoint = list(OUTPUT.keys())[0]
	for line in file:
		line = line.strip().split(';')
		thread_number = line[0]
		probe_no = line[1]
		endpoint = line[2]
		value = float(line[3])

		if not is_sql_record(endpoint) and not is_handling_record(endpoint) and current_endpoint != endpoint:
			current_endpoint = endpoint
			OUTPUT[current_endpoint] = dict()

		outter_key = current_endpoint
		inner_key = probe_no


		item : Union[None, Tuple[float, float, float]] = OUTPUT[outter_key].get(inner_key, None)

		if item is None:
			OUTPUT[outter_key][inner_key] = (value, None, None)
		else:
			if is_sql_record(endpoint):
				OUTPUT[outter_key][inner_key] = (avg(item[0], value), item[1], item[2])
			else:
				if is_handling_record(endpoint):
					OUTPUT[outter_key][inner_key] = (item[0], item[1], avg(item[2], value))
				elif item[1] == 0:
					OUTPUT[outter_key][inner_key] = (item[0], value, item[2])
				else:
					OUTPUT[outter_key][inner_key] = (item[0], avg(item[1], value), item[2])


with open(OUTPUT_PATH, 'wt') as file:
	file.write('endpoint|probe no.|avg. total SQL time [ms]|avh. processing time [ms]|avg. total time [ms]\n')
	for endpoint, scores in OUTPUT.items():
		for probe_no, values in scores.items():
			file.write(f'{endpoint}|{probe_no}|{values[0] :.2f}|{values[1] :.2f}|{values[2] :.2f}' + '\n')
