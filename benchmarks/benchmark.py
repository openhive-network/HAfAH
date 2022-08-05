#!/usr/bin/python3

import html
import logging
import os
import sys
from argparse import ArgumentParser
from dataclasses import dataclass
from enum import Enum
from os import environ
from pathlib import Path
from re import compile, match
from shutil import rmtree, copy2 as copy_file
from subprocess import PIPE, STDOUT, Popen
from time import sleep
from typing import Any, Dict, List, Tuple
from urllib.parse import urlencode, urlparse

from prettytable import PrettyTable
from requests import post

LOG_LEVEL = logging.DEBUG if 'DEBUG' in os.environ else logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"

def configure_logger():
	logger = logging.getLogger('performance')
	logger.setLevel(LOG_LEVEL)
	logger.handlers.clear()
	ch = logging.StreamHandler(sys.stdout)
	ch.setLevel(LOG_LEVEL)
	ch.setFormatter(logging.Formatter(LOG_FORMAT))
	logger.addHandler(ch)
	return logger

class CSV:
	class MODE(Enum):
		PERF = 0, 	# performance testing mode
		CL = 1		# constant load mode

class CALL_STYLE_OPT(Enum):
	OLD_STYLE = 0,	#	/						{id:0, jsonrpc: 2.0, data:{id:some_id}, method:get_transaction}
	NEW_STYLE = 1,	#	rpc/get_transaction		{id:some_id}
	POSTGRES  = 2	#	-						SELECT * FROM get_transaction_json( some_id, true, true )

	@staticmethod
	def from_str(input : str):
		input = input.strip().lower()
		for key, value in CALL_STYLE_OPT.__members__.items():
			if CALL_STYLE_OPT.to_str(key) == input:
				return value
		raise Exception(f'invalid input: `{input}`')

	@staticmethod
	def to_str(input : 'CALL_STYLE_OPT'):
		input = str(input)
		if '.' in input:
			input = input.split('.')[1]
		return input.lower().replace('_', '-')

# constants
log = configure_logger()
BOOL_PARAM = dict(nargs='?', type=bool, const=True, default=False)
DEFAULT_ROOT_DIR = Path(__file__).parent.resolve().parent.as_posix()
DEFAULT_LOOP_COUNT = 500
INFINITY_LOOP_COUNT = -1

def format_csv_file(filename : str, csv_info : tuple):
	csv_path_handle : Path = csv_info[0]
	csv_mode = csv_info[1]
	csv_blocks = csv_info[2]
	csv_tags : list = csv_info[3].split('_')

	return filename

engine = ArgumentParser()
environment   = engine.add_argument_group('environment')
connection   = engine.add_argument_group('connection')
benchmarking = engine.add_argument_group('benchmarking')
analytics    = engine.add_argument_group('analytics')

# environment configuration
environment.add_argument('-l', '--list',           dest='list_csv',        **BOOL_PARAM,                                          help=f'if specified program will just list avaiable CSV files')
environment.add_argument('-r', '--root-dir',       dest='root_dir',        type=str,     default=DEFAULT_ROOT_DIR,                help=f'path to root directory of tests_api project [default={DEFAULT_ROOT_DIR}]')
environment.add_argument('-d', '--datadir',        dest='datadir',         type=str,     default='./wdir',                        help='defines path to workdir (path to this dir will alway be recreated) [default=./wdir]')
environment.add_argument('-j', '--jmeter',         dest='jmeter',          type=str,     default='/usr/bin/jmeter',               help='path to jmeter executable [default=/usr/bin/jmeter]')
environment.add_argument('-q', '--supr-errors',    dest='supr_err',        **BOOL_PARAM,                                          help="if specified error messages of bad requests won't be printed")
environment.add_argument('--skip-version-check',   dest='skip_version',    **BOOL_PARAM,                                          help='if specified, `hive_api.get_version` call will not be performed')

# benchmarking options
benchmarking.add_argument('-n', '--api-name',       dest='api',             type=str,     default='account_history_api',          help='specifies which API should be tested [default=account_history_api]')
benchmarking.add_argument('-c', '--csv',            dest='select_csv',      type=str,     default='perf_60M_heavy.csv',           help=f'selected CSV FILENAME (use -l to list avaiable), [default=perf_60M_heavy.csv]')
benchmarking.add_argument('-k', '--loops',          dest='loops',           type=int,     default=None,                           help=f'amount of loops over CSV file per thread (if exceed, thread loop over the file again); for cl mode: pass -1 for infite loop [default={DEFAULT_LOOP_COUNT}]')
benchmarking.add_argument('-t', '--threads',        dest='threads',         type=int,     default=10,                             help='defines amount of threads to use during tests [default=10]')
benchmarking.add_argument('--call-style',           dest='call_style',      type=str,     default='old-style',                    help='defines calling style, performaed by jmeter [default=old-style]', choices=('old-style', 'new-style', 'postgres'))

# connection options
connection.add_argument('-p', '--port',           dest='port',            type=int,     default=8095,                             help='port to use during tests; set to 5432 for direct postgres query [default=8095]')
connection.add_argument('-a', '--address',        dest='addr',            type=str,     default='localhost',                      help='addres to connect during test [default=localhost]')
connection.add_argument('--postgres',             dest='postgres_url',    type=str,     default='postgresql:///haf_block_log',    help='if specified connection string, tests will be performed on postgres db [default=postgresql:///haf_block_log]')
connection.add_argument('--postgres-schema',      dest='schema',          type=str,     default='hive',                           help='specifies schema, where functions are placed [default=hive]')

# analytics options
analytics.add_argument('-i', '--ignore-bad-req', dest='ignore_br',       **BOOL_PARAM,                                            help='if specified script will ignore requests that failed, error message is still printed')
args = engine.parse_args()

# user input
ROOT_DIR          : Path              = Path(args.root_dir)
DATADIR           : Path              = Path(args.datadir).resolve()
POSTGRES_URL      : str               = args.postgres_url
PORT              : int               = args.port
THREADS           : int               = args.threads
CSV_FILENAME      : str               = args.select_csv
JMETER_BIN        : Path              = Path(args.jmeter)
ADDRESS           : str               = args.addr
CALL_STYLE        : CALL_STYLE_OPT    = CALL_STYLE_OPT.from_str(args.call_style)
SKIP_VERSION      : bool              = args.skip_version
API_NAME          : str               = args.api
LOOP_COUNT        : int               = args.loops
IGNORE_BAD_REQ    : bool              = args.ignore_br
SUPR_ERRRORS      : bool              = args.supr_err
SCHEMA            : str               = args.schema

# print configuration
log.info(f'''configuration:
### PATHS ###
jmeter = {JMETER_BIN}
root project directory = {ROOT_DIR}
datadir = {DATADIR}

### NETWORK ###
postgres url = {POSTGRES_URL}
address = {ADDRESS}
port = {PORT}

### TESTING ###
csv = {CSV_FILENAME}
call style = {CALL_STYLE}
threads = {THREADS}
api = {API_NAME}
''')

# paths
TEST_DIR_PATH = ROOT_DIR / 'benchmarks'
PERFORMANCE_DATA_DIR_PATH = TEST_DIR_PATH / 'performance_data' / API_NAME
CSV_DIR_PATH = PERFORMANCE_DATA_DIR_PATH / 'CSV'
JMX_DIR_PATH = PERFORMANCE_DATA_DIR_PATH / 'JMX'
PERF_JMX_CONFIG = JMX_DIR_PATH / 'performance.jmx.in'
CL_JMX_CONFIG = JMX_DIR_PATH / 'constant_load.jmx.in'
HAFAH_MAIN = ROOT_DIR / 'main.py'

# datadir paths
OUT_JMX_PATH = DATADIR / f'jmeter_config_{PORT}.jmx'
JMETER_REPORT_OUT_FILE = DATADIR / f'jmeter_{PORT}_output.csv'
HAFAH_OUT_FILE = DATADIR / f'hafah_{PORT}_output.csv'
REPORT_OUTPUT_FILE = DATADIR / f'report_{PORT}.csv'
PROPERTIES_FILES = DATADIR / 'jmeter.properties'

# generate list of CSV's
AVAILA_CSV = dict()
csv_regex = compile('(.*)_([0-9]+)M_(.*)\.csv')
for csv_file in CSV_DIR_PATH.glob('*.csv'):
	csv_filename = csv_file.name
	csv_filename_match = csv_regex.match(csv_filename)
	assert csv_filename_match is not None, f'invalid name of {csv_filename}, it should be <perf|cl>_<amount of blocks>M_<tag>.csv'
	csv_regex_group = csv_filename_match.group(1, 2, 3)
	AVAILA_CSV[csv_filename] = (csv_file, (CSV.MODE.PERF if csv_regex_group[0] == 'perf' else CSV.MODE.CL), *csv_regex_group[1:])

# list avaiable CSV files and exit
if args.list_csv:
	res = f"Found and avaiable csv's:" + '\n'*2
	for filename, csv_info in AVAILA_CSV.items():
		res += format_csv_file(filename, csv_info) + '\n'
	log.info(res)
	exit(0)

# config
CSV_MODE : CSV.MODE = AVAILA_CSV[CSV_FILENAME][1]
CSV_PATH : Path = AVAILA_CSV[CSV_FILENAME][0]
JMX_PATH = PERF_JMX_CONFIG if CSV_MODE == CSV.MODE.PERF else CL_JMX_CONFIG

# calculating loop count
if LOOP_COUNT is None:
	if CSV.MODE.CL != CSV_MODE:
		LOOP_COUNT = DEFAULT_LOOP_COUNT
	else:
		LOOP_COUNT = INFINITY_LOOP_COUNT
else:
	LOOP_COUNT = max(-1, LOOP_COUNT)

# process postgresql conection string to fill jdbc requirements
# refering to: https://jdbc.postgresql.org/documentation/80/connect.html
postgres_url_jmeter = None
if match("postgresql://([a-zA-Z0-9_-]+)(:([a-zA-Z0-9_-]+))?@(.*)/(.*)", POSTGRES_URL) is not None: # Ex. postgresql://user:pass@127.0.0.1/my_database
	parsed_postgres_url = urlparse(POSTGRES_URL)
	parsed_postgres_url_port = '' if parsed_postgres_url.port is None else f':{parsed_postgres_url.port}'
	params_to_encode = {"user":parsed_postgres_url.username}
	if parsed_postgres_url.password is not None and len(parsed_postgres_url.password) > 0:
		params_to_encode["password"] = parsed_postgres_url.password
	credentials = urlencode(params_to_encode)
	postgres_url_jmeter = f'postgresql://{parsed_postgres_url.hostname}{parsed_postgres_url_port}{parsed_postgres_url.path}?{credentials}'
elif match('postgresql:///(.*)', POSTGRES_URL):  # Ex. postgresql:///my_database
	postgres_url_jmeter = POSTGRES_URL.replace('/', '', -1)
else:
	assert False, "cannot parse postgres url"

# postgres_url_jmeter = html.escape(postgres_url_jmeter)
log.info(f'postgres connection string in JMETER: jdbc:{postgres_url_jmeter}')

# theese will be appended to properties file for jmeter
PARAMS = dict(
	port=str(PORT),
	host=ADDRESS,
	threads=str(THREADS),
	dataset=CSV_PATH.as_posix(),
	psql=postgres_url_jmeter,
	call_style=CALL_STYLE_OPT.to_str(CALL_STYLE),
	loop_count=LOOP_COUNT,
	schema=SCHEMA
)

# directory managment
if DATADIR.exists():
	rmtree(DATADIR.as_posix())
	log.info(f'removed old datadir {DATADIR}')
DATADIR.mkdir()
copy_file( src=JMX_PATH.as_posix(), dst=OUT_JMX_PATH.as_posix() )

# generate .properties file
with PROPERTIES_FILES.open('wt') as ofile:
	for key, value in PARAMS.items():
		ofile.write(f'{key}={value}' + '\n')

# running HAfAH and tests
jmeter_interrupt = False
try:
	# gathering version
	if not SKIP_VERSION:
		version : dict = post(
			url=f'http://{ADDRESS}:{PORT}/',
			headers={'Content-Type': 'application/json'},
			json={"jsonrpc":"2.0","id":0,"method":"hive_api.get_version","params":{}}
		).json()
		if not 'result' in version or not 'commit' in version['result']:
			log.error(f'service is not responding properly to `hive_api.get_version` call: `{version}`')
		else:
			assert 'unspecified' not in version["result"]["commit"], 'HAfAH version has not been set'
			log.info(f'testing app: {version["result"]["app_name"]} version: {version["result"]["commit"]}')

	# setup and run JMETER
	log.info("starting performance testing")
	if CSV_MODE == CSV.MODE.CL:
		log.info("to stop generating load, press ctrl+c")

	jmeter_env = environ
	jmeter_env['JAVA_ARGS']='-Xms4g -Xmx4g'
	JMETER = Popen(
		args=(
			JMETER_BIN, '-n',
			'-t', OUT_JMX_PATH.as_posix(),
			'-l', JMETER_REPORT_OUT_FILE.as_posix(),
			'-p', PROPERTIES_FILES.as_posix()
		),
		env=jmeter_env,
		cwd=DATADIR.as_posix(),
		stdout=PIPE,
		stderr=STDOUT,
		text=True,
		encoding='utf-8'
	)
	try:
		line = JMETER.stdout.readline()
		while JMETER.poll() is None and not '... end of run' in line:
			if len(line) > 0 and not line.startswith('Warning'):
				log.debug(line)
			line = JMETER.stdout.readline()
	except KeyboardInterrupt:
		log.debug("stopping on user request")
		JMETER.kill()
		jmeter_interrupt = True
	finally:
		if JMETER.poll() is None:
			JMETER.kill()
			log.debug('checking is jmeter has been killed')
			sleep(1)
			if JMETER.poll() is None:
				JMETER.terminate()


except Exception as e:
	log.error(f'cought exception: {e}')
	raise e

# processing output

# read and organize output from JMETER
@dataclass
class jmeter_record:
	value : int
	thread_no : int

# process incoming data from JMETER
jmeter_output : Dict[str, List[jmeter_record]] = dict()
error_counter = 0
with JMETER_REPORT_OUT_FILE.open('rt', encoding='utf-8') as in_file:
	raw_line = in_file.readline()
	headers_raw = raw_line.split(',')
	get_index = lambda x: headers_raw.index(x)

	elapsed_idx = get_index('elapsed')
	label_idx = get_index('label')
	threadname_idx = get_index('threadName')
	success_idx = get_index('success')

	def handle_error(msg : str):
		global error_counter
		error_counter += 1
		if not SUPR_ERRRORS:
			log.error('during analysis of jmeter output, found error in line: \n' + msg)

	for count, raw_line in enumerate(in_file):
		line = raw_line.split(',')

		if line[success_idx] != 'true':
			if CSV_MODE == CSV.MODE.CL and ( jmeter_interrupt or LOOP_COUNT > 0 ):
				if not IGNORE_BAD_REQ:
					log.info(f'total amount of calls on {THREADS} threads: {count-1}')
					break
				else:
					handle_error(raw_line)
			else:
				handle_error(raw_line)
				if not IGNORE_BAD_REQ:
					assert False, f'test failed, check logs in {DATADIR.as_posix()} for more informations '

		label = line[label_idx] # endpoint

		if 'pre_check' == line[label_idx] or 'SQL_validate' == line[label_idx]: # exclude pre_check from performance report
			continue

		thread_no = int(line[threadname_idx].split('-')[-1])
		elapsed = float(line[elapsed_idx])
		record = jmeter_record(value=int(elapsed), thread_no=thread_no)

		if label not in jmeter_output:
			jmeter_output[label] = [ record ]
		else:
			jmeter_output[label].append( record )

	if error_counter > 0:
		log.error(f'Amount of invalid requests/total amount of requests: {error_counter}/{count + 1}')

# generate pretty table
table = PrettyTable(field_names=['Endpoint', 'Max [ms]', 'Min [ms]', 'Average [ms]', 'Median [ms]'])
value_extr = lambda x: x.value
def median_on_sorted(iter):
	length = len(iter)
	if length % 2:
		return iter[ int(length / 2) + 1 ].value
	else:
		return (iter[ int(length / 2) - 1 ].value + iter[ int(length / 2) ].value) / 2.0

def summ(iter):
	res = 0
	for x in iter:
		res += x.value
	return res

# fill data
for endpoint, values in jmeter_output.items():
	vsorted = sorted(values, key=value_extr)
	table.add_row([
		endpoint,
		int(vsorted[-1].value),
		int(vsorted[0].value),
		int(summ(vsorted)/len(vsorted)),
		int(median_on_sorted(vsorted))
	])

# formating
table.align = 'c'
table.align[table.field_names[0]] = 'l'
log.info('\n' + f'{table}')
