#!/usr/bin/python3

from argparse import ArgumentParser
from os.path import dirname, realpath
from pathlib import Path
from sys import argv
from hafah.logger import get_logger

from hafah.serve import run_server

BOOL_PARAM = dict(nargs='?', type=bool, const=True, default=False)
logger = get_logger(module_name='main')

if __name__ == '__main__':

  engine = ArgumentParser()
  engine.add_argument('-p', '--psql-db-path', dest='psql', type=str, required=True, help='connection string to postgres db ( ex. postgresql://postgres:pass@127.0.0.1:5432/hafah )')
  engine.add_argument('-n', '--port', dest='port', type=int, required=True, help='port to listen on (ex. 6380)')
  engine.add_argument('-r', '--log-responses', dest='log_responses', help='logging of responses (dev option, by default OFF)', **BOOL_PARAM)
  args = engine.parse_args(argv[1:])

  try:
    logger.info("starting server, press ^C to stop server")
    run_server(args.psql, args.port, args.log_responses, Path(dirname(realpath(__file__))) / 'queries' / 'ah_schema_functions.pgsql')
  except KeyboardInterrupt:
    pass
  except Exception as e:
    logger.error(f'got Exception: {e}')
