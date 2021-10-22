#!/usr/bin/python3
import threading

from ah.server.serve import run_server, event_loop
from argparse import ArgumentParser
from sys import argv

if __name__ == '__main__':

  engine = ArgumentParser()
  engine.add_argument('-p, --psql-db-path', dest='psql', type=str, required=True, help='connection string to postgres db ( ex. postgresql://postgres:pass@127.0.0.1:5432/hafah )')
  engine.add_argument('-n, --port', dest='port', type=int, required=True, help='port to listen on (ex. 6380)')
  args = engine.parse_args(argv[1:])

  t = threading.Thread(target=event_loop, args=(args.port ,run_server(args.psql), ))
  t.start()
  # run_server(args.psql, args.port)