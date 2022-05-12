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
from sys import argv
from time import sleep
from typing import Any, Dict, List, Tuple
from urllib.parse import urlencode, urlparse

from prettytable import PrettyTable

LOG_LEVEL = logging.DEBUG if 'DEBUG' in os.environ else logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"

# TODO: use hafah.logger.get_logger
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
	OLD_STYLE = 0,	#	/						{id:0, jsonrpc: 2.0, data:{id:gwropiwejfoifewofeofifhqifwp}, method:get_transaction}
	NEW_STYLE = 1,	#	rpc/get_transaction		{id:gwropiwejfoifewofeofifhqifwp}
	POSTGRES  = 2	#	-						SELECT * FROM get_transaction_json( gwropiwejfoifewofeofifhqifwp, true, true )

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
LEGEND = {
	'cl': "constant load, CSV files marked like this will be executed in infinite loop to generate constant load",
	'perf': "performance, if CSV file is marked with perf, it will serve as provider of 500 lines, if file contain less, it will loop aroung file",
	'60M': 'amount of blocks, this defines, how many bloacks has to be avaiable when testing',
	'heavy': "[perf only] this tag is for CSV files, which provides samples with a lot of return data (e.x. huge blocks)",
	'light': "[perf only] this tag is for CSV files, which provides samples which processing times should be very low",
	'prod': "[cl only] if CSV file is tagged with this, that means it was generated basing on real calls from production",
	'psql': '[cl only] CSV is prepared as postgres input',
	'jrpc': '[cl only] CSV is prepared as jsonrpc call input',
	'custom': '[cl only] CSV file is custom'
}

def format_csv_file(filename : str, csv_info : tuple):
	csv_path_handle : Path = csv_info[0]
	csv_mode = csv_info[1]
	csv_blocks = csv_info[2]
	csv_tags : list = csv_info[3].split('_')

	res = f'{filename}\t - \t'
	if csv_mode == 'perf':
		return res + f'for performance test on {csv_blocks}M db'
	else:
		res += f'for generating load on {csv_blocks}M '
		return res + ('postgres DB' if 'psql' in csv_tags else 'http server')

engine = ArgumentParser()
engine.add_argument('-l', '--list',        dest='list_csv',     **BOOL_PARAM,                                        help=f'if specified program will just list avaiable CSV files')
engine.add_argument('-c', '--csv',         dest='select_csv',   type=str,   default='perf_60M_heavy.csv',            help=f'selected CSV FILENAME (use -l to list avaiable), [default=perf_60M_heavy.csv]')
engine.add_argument('-r', '--root-dir',    dest='root_dir',     type=str,   default=DEFAULT_ROOT_DIR,                help=f'path to root directory of HAfAH project [default={DEFAULT_ROOT_DIR}]')
engine.add_argument('-p', '--port',        dest='port',         type=int,   default=8095,                            help='port to start HAfAH instance, and perform test; set to 5432 for direct postgres query [default=8095]')
engine.add_argument('-a', '--address',     dest='addr',         type=str,   default='localhost',                     help='addres to connect during test [default=localhost]')
engine.add_argument('-s', '--top-slowest', dest='top_slowest',  type=int,   default=5,                               help='defines amount of top slowest calls to show [default=5]')
engine.add_argument('-d', '--datadir',     dest='datadir',      type=str,   default='./wdir',                        help='defines path to workdir (path to this dir will alway be recreated) [default=./wdir]')
engine.add_argument('-t', '--threads',     dest='threads',      type=int,   default=10,                              help='defines amount of threads to use during tests [default=10]')
engine.add_argument('-j', '--jmeter',      dest='jmeter',       type=str,   default='/usr/bin/jmeter',               help='path to jmeter executable [default=/usr/bin/jmeter]')
engine.add_argument('--call-style',        dest='call_style',   type=str,   default='old-style',                     help='defines calling style, performaed by jmeter [default=old-style]', choices=('old-style', 'new-style', 'postgres'))
engine.add_argument('--postgres',          dest='postgres_url', type=str,   default='postgresql:///haf_block_log',   help='if specified connection string, tests will be performed on postgres db [default=postgresql:///haf_block_log]')
engine.add_argument('--no-launch',         dest='no_hafah',     **BOOL_PARAM,                                        help='if specified, no HAfAH instance will be launched (if specified, no full data will be avaiable) [default=False]')
engine.add_argument('--explicit-python',   dest='ex_python',    **BOOL_PARAM,                                        help='starts HAfAH like `python3 main.py` instead of `main.py`, make sure that dir with python interpreter is in PATH env')
args = engine.parse_args(list(argv[1:]))

# user input
ROOT_DIR          : Path              = Path(args.root_dir)
TOP_SLOWEST_COUNT : int               = args.top_slowest
DATADIR           : Path              = Path(args.datadir).resolve()
POSTGRES_URL      : str               = args.postgres_url
PORT              : int               = args.port
THREADS           : int               = args.threads
CSV_FILENAME      : str               = args.select_csv
JMETER_BIN        : Path              = Path(args.jmeter)
ADDRESS           : str               = args.addr
START_HAFAH       : bool              = (not args.no_hafah) and PORT != 5432
PYTHON_EXPLICIT   : bool              = args.ex_python
CALL_STYLE        : CALL_STYLE_OPT    = CALL_STYLE_OPT.from_str(args.call_style)

# paths
TEST_DIR_PATH = ROOT_DIR / 'tests'
PERFORMANCE_DATA_DIR_PATH = TEST_DIR_PATH / 'performance_data'
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
	res = f"Found and avaiable csv's:" + '\n'*1
	for filename, csv_info in AVAILA_CSV.items():
		res += format_csv_file(filename, csv_info) + '\n'

	res += '\n'*2 + "legend:\n"
	for lg_sym, lg_def in LEGEND.items():
		res += f'{lg_sym} - {lg_def}' + '\n'

	log.info(res)
	exit(0)

# config
CSV_MODE : CSV.MODE = AVAILA_CSV[CSV_FILENAME][1]
CSV_PATH : Path = AVAILA_CSV[CSV_FILENAME][0]
JMX_PATH = PERF_JMX_CONFIG if CSV_MODE == CSV.MODE.PERF else CL_JMX_CONFIG

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

postgres_url_jmeter = html.escape(postgres_url_jmeter)
log.info(f'postgres connection string in JMETER: jdbc:{postgres_url_jmeter}')

# theese will be appended in form: -J<first>=<second>
# Ex: -Jport=8090
PARAMS = dict(
	port=str(PORT),
	host=ADDRESS,
	threads=str(THREADS),
	dataset=CSV_PATH.as_posix(),
	psql=postgres_url_jmeter,
	call_style=CALL_STYLE_OPT.to_str(CALL_STYLE)
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
	# setup and run HAfAH process
	HAFAH : Popen = None
	if START_HAFAH and not CALL_STYLE == CALL_STYLE_OPT.POSTGRES:
		hafah_file_handle = HAFAH_OUT_FILE.open('wt', encoding='utf-8')

		hafah_env = environ
		hafah_env['DEBUG'] = '1'
		args = [HAFAH_MAIN.as_posix(), '--psql-db-path', POSTGRES_URL, '--port', str(PORT)]
		if PYTHON_EXPLICIT:
			from sys import executable
			assert executable is not None, 'unable to find python3 executable'
			args = [executable, *args]

		log.info(f'starting HAfAH with arguments: {args}')
		HAFAH = Popen(
			args=args,
			env=hafah_env,
			cwd=DATADIR.as_posix(),
			stdout=hafah_file_handle,
			# stdout=STDOUT,
			# stdout=PIPE,
			text=True,
			encoding='utf-8'
		)

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
finally:
	if HAFAH is not None:
		log.info('killing HAfAH')
		HAFAH.kill()
		HAFAH.wait(5)
		hafah_file_handle.close()


# processing output

# read and organize output from JMETER
@dataclass
class jmeter_record:
	value : int
	thread_no : int

# process incoming data from JMETER
jmeter_output : Dict[str, List[jmeter_record]] = dict()
with JMETER_REPORT_OUT_FILE.open('rt', encoding='utf-8') as in_file:
	headers_raw = in_file.readline().split(',')
	get_index = lambda x: headers_raw.index(x)

	elapsed_idx = get_index('elapsed')
	label_idx = get_index('label')
	threadname_idx = get_index('threadName')
	success_idx = get_index('success')

	for count, line in enumerate(in_file):
		line = line.split(',')

		if line[success_idx] != 'true':
			if CSV_MODE == CSV.MODE.CL and jmeter_interrupt:
				log.info(f'total amount of calls on {THREADS} threads: {count-1}')
				break
			else:
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

# if log from hafah is unavaiable quit
if not START_HAFAH or CSV_MODE != CSV.MODE.PERF:
	exit(0)

# advanced processing

id_regex = compile( '.* \[id=(.*)\] QUE.*' )
pid_regex = compile( '\[pid=([0-9]+)\].*' )
sql_regex = compile( '.* QUERY: `(.*)`' )
time_regex = compile( '.*\] (.*) executed in ([0-9\.]+)ms' )
content_length_regex = compile( '.* length: ([0-9]+)' )

@dataclass
class hafah_perf_id:
	thread_num : int
	sample_num : int
	endpoint : str

	def __post_init__(self):
		self.thread_num = int(self.thread_num)
		self.sample_num = int(self.sample_num)

@dataclass
class hafah_record:
	id : hafah_perf_id = id_regex
	pid : int = pid_regex
	query : str = sql_regex
	receiving_request : int = None
	SQL : int = None
	backend : int = None
	dispatch : int = None
	sending_response : int = None
	process_request : int = None
	content_length : int = content_length_regex
	total : int = 0

# load log from HAfAH
hafah_output : List[hafah_record] = []
with HAFAH_OUT_FILE.open('rt') as in_file:
	readline = lambda: in_file.readline().rstrip('\n')
	for line in in_file:
		while line is not None and '##########' not in line: line = readline()
		if line is None: break
		line = readline()
		item = hafah_record()
		# probe properties
		for key in ['id', 'pid', 'query']:
			setattr( item, key, getattr( item, key ).match(line).group(1) )

		# extracting id
		if item.id == 'VALIDATION':
			continue
		item.id = hafah_perf_id(*item.id.split('/'))

		# time values
		line = readline()
		while 'length' not in line:
			name, value = time_regex.match(line).groups()
			value = int(float(value))
			item.total += value
			setattr( item, name, value )
			line = readline()

		# setting content length and appending
		item.content_length = content_length_regex.match(line).group(1)
		hafah_output.append(item)

# regroup both HAfAH and JMETER output endpoint -> thread_no -> sample_no -> sample
generate_schema = lambda: dict([(endpoint, dict([(i, dict()) for i in range(1, THREADS+1)])) for endpoint in jmeter_output.keys()])
jmeter_output_regrouped : Dict[ str, Dict[int, Dict[int, int]]]					= generate_schema()
hafah_output_regrouped  : Dict[ str, Dict[int, Dict[int, hafah_record]]]		= generate_schema()
assert id(jmeter_output_regrouped) != id(hafah_output_regrouped)

# JMETER
for endpoint, values in jmeter_output.items():
	thread_no_counters = dict([(x, 1) for x in range(len(values))])
	for i, item in enumerate(values):
		jmeter_output_regrouped[endpoint][item.thread_no][thread_no_counters[item.thread_no]] = item.value
		thread_no_counters[item.thread_no] += 1

# HAfAH
for item in hafah_output:
	hafah_output_regrouped[item.id.endpoint][item.id.thread_num][item.id.sample_num] = item

@dataclass
class final_csv_row:
	endpoint : str
	identifier : str # thread_no / sample_no
	hafah_receive : int
	hafah_SQL : int
	hafah_backend : int
	hafah_dispatch : int
	hafah_sending : int
	hafah_processing : int
	hafah_total : int
	jmeter_elapsed : int
	query : str

	def __post_init__(self):
		for mname, mvalue in self.__dict__.items():
			setattr(self, mname, str(mvalue))


# merge HAfAH and JMETER
final_output : List[final_csv_row] = []
sort_items = lambda x: list(sorted(x, key=lambda y: y[0]))
for hafah, jmeter in zip( hafah_output_regrouped.items(), jmeter_output_regrouped.items() ):
	assert hafah[0] == jmeter[0]
	log.debug(f'processing endpoint {hafah[0]}...')
	for hafah_th, jmeter_th in zip( hafah[1].items(), jmeter[1].items() ):
		assert hafah_th[0] == jmeter_th[0]
		log.debug(f'processing thread number {hafah_th[0]}...')
		for hafah_smpl, jmeter_smpl in zip( sort_items(hafah_th[1].items()), sort_items(jmeter_th[1].items()) ):
			assert hafah_smpl[0] == jmeter_smpl[0], f'{hafah_smpl[0]=}, {jmeter_smpl[0]=}'
			log.debug(f'processing sample number {hafah_smpl[0]}...')
			hafah_item : hafah_record = hafah_smpl[1]
			jmeter_item : int = jmeter_smpl[1]
			final_output.append(
				final_csv_row(
					endpoint					=	hafah[0],
					identifier				=	f'{hafah_th[0]}/{hafah_smpl[0]}',
					hafah_receive			=	hafah_item.receiving_request,
					hafah_SQL				=	hafah_item.SQL,
					hafah_backend			=	hafah_item.backend,
					hafah_dispatch			=	hafah_item.dispatch,
					hafah_sending			=	hafah_item.sending_response,
					hafah_processing		=	hafah_item.process_request,
					hafah_total				=	hafah_item.total,
					jmeter_elapsed			=	jmeter_item,
					query						=	hafah_item.query
				)
			)

# generate CSV report
with REPORT_OUTPUT_FILE.open('wt', encoding='utf-8') as out_file:
	headers = list(final_csv_row.__annotations__.keys())
	out_file.write("|".join(headers) + '\n')
	for values in final_output:
		out_file.write('|'.join(list(values.__dict__.values())) + '\n')
log.info(f'generated full report in {REPORT_OUTPUT_FILE.as_posix()}')

# find N longest queies
top_longest : Dict[str, List[Tuple[int, str]]] = dict([(x, []) for x in jmeter_output.keys()])
final_output.sort(key=lambda x:int(x.jmeter_elapsed), reverse=True)
for item in final_output:
	if len(top_longest[item.endpoint]) < TOP_SLOWEST_COUNT:
		top_longest[item.endpoint].append( (item.jmeter_elapsed, item.query) )

	if sum([len(val) for val in top_longest.values()]) == len(top_longest) * TOP_SLOWEST_COUNT:
		break

for endpoint, records in top_longest.items():
	res = f'For `{endpoint}` endpoint top {TOP_SLOWEST_COUNT} slowest queries:\n'
	for i, record in enumerate(records):
		res += f'{i+1}. {record[0]}ms | {record[1]}\n'
	log.info(res)

