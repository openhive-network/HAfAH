#!/usr/bin/python3

import enum
from sys import argv
from typing import Dict, Tuple, Union
from re import compile

PATH = argv[1]
OUTPUT_PATH = argv[2]
OUTPUT : Dict[str, Dict[int, Tuple[float, float, float]]] = dict()
UNIQ_THREADS = set()
REGEX = '\[([0-9]+)/([0-9]+)/([a-z_]+)\] (.*) executed in ([0-9]+\.[0-9]+)ms'

def is_sql_record(endpoint) -> bool:
	return endpoint == 'SQL'

def is_handling_record(endpoint) -> bool:
	return endpoint == 'process_request'

def is_backend_record(endpoint) -> bool:
	return endpoint == 'backend'

def add_to_average_calcualation(val1 : float, val2 : float) -> float:
	if val1 is None:
		return val2
	elif val2 is None:
		return val1
	return val1 + val2

regex = compile(REGEX)
with open(PATH, 'rt') as file:
	for line_no, line in enumerate(file):
		match = regex.match(line.strip())
		if match is None: continue
		thread_number = int(match.group(1))
		probe_no = int(match.group(2))
		endpoint = match.group(3)
		record_type = match.group(4)
		value = float(match.group(5))

		UNIQ_THREADS.add(thread_number)

		if not endpoint in OUTPUT:
			OUTPUT[endpoint] = dict()

		if not probe_no in OUTPUT[endpoint]:
			OUTPUT[endpoint][probe_no] = (0, 0, 0)

		item : Tuple[float, float, float] = OUTPUT[endpoint][probe_no]

		if is_sql_record(record_type):
			OUTPUT[endpoint][probe_no] = (add_to_average_calcualation(item[0], value), item[1], item[2])
		elif is_backend_record(record_type):
			OUTPUT[endpoint][probe_no] = (item[0], add_to_average_calcualation(item[1], value), item[2])
		elif is_handling_record(record_type):
			OUTPUT[endpoint][probe_no] = (item[0], item[1], add_to_average_calcualation(item[2], value))
		else:
			assert False, f'invalid decision path! record_type == `{record_type}`'

THREAD_COUNT = float(len(UNIQ_THREADS))
def avg(iterable : list) -> float:
	return iterable / THREAD_COUNT

with open(OUTPUT_PATH, 'wt') as file:
	file.write('endpoint|probe no.|avg. total SQL time [ms]|avg. processing time [ms]|avg. total time [ms]\n')
	for endpoint, scores in OUTPUT.items():
		for probe_no, values in scores.items():
			file.write(f'{endpoint}|{probe_no}|{avg(values[0]) :.2f}|{avg(values[1]) :.2f}|{avg(values[2]) :.2f}' + '\n')
