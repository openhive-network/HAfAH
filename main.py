#!/usr/bin/python3

from argparse import ArgumentParser
from os.path import dirname, realpath
from pathlib import Path
from sys import argv

from hafah.serve import run_server

if __name__ == '__main__':

  engine = ArgumentParser()
  engine.add_argument('-p', '--psql-db-path', dest='psql', type=str, required=True, help='connection string to postgres db ( ex. postgresql://postgres:pass@127.0.0.1:5432/hafah )')
  engine.add_argument('-n', '--port', dest='port', type=int, required=True, help='port to listen on (ex. 6380)')
  engine.add_argument('-r', '--log-responses', dest='log_responses', action='store_true', help='logging of responses (dev option, by default OFF)')
  args = engine.parse_args(argv[1:])

  try:
    print("starting server, press ^C to stop server")
    run_server(args.psql, args.port, args.log_responses, Path(dirname(realpath(__file__))) / 'queries' / 'ah_schema_functions.pgsql')
  except KeyboardInterrupt:
    pass
  except Exception as e:
    print(f'got Exception: {e}')
