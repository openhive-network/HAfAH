# -*- coding: utf-8 -*-
"""Hive JSON-RPC API server."""
import os
import sys
import logging
import time
import traceback
import json

from datetime import datetime
from time import perf_counter
from sqlalchemy.exc import OperationalError
from aiohttp import web
from jsonrpcserver.methods import Methods
from jsonrpcserver import dispatch

from ah.api.endpoints2 import build_methods as account_history

import simplejson
from ah.server.adapter import Db

from http.server import BaseHTTPRequestHandler, HTTPServer

from functools import partial

from concurrent.futures import ThreadPoolExecutor, as_completed

LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"
MAIN_LOG_PATH = "ah.log"

MODULE_NAME = "AH synchronizer"
logger = logging.getLogger(MODULE_NAME)
logger.setLevel(LOG_LEVEL)

ch = logging.StreamHandler(sys.stdout)
ch.setLevel(LOG_LEVEL)
ch.setFormatter(logging.Formatter(LOG_FORMAT))

fh = logging.FileHandler(MAIN_LOG_PATH)
fh.setLevel(LOG_LEVEL)
fh.setFormatter(logging.Formatter(LOG_FORMAT))

if not logger.hasHandlers():
  logger.addHandler(ch)
  logger.addHandler(fh)

class APIMethods:
  @staticmethod
  def build_methods():
      """Register all supported hive_api/condenser_api.calls."""
      # pylint: disable=expression-not-assigned, line-too-long
      methods = Methods()

      # account_history methods
      methods.add(**account_history())

      return methods

class sql_executor:
  def __init__(self, db_url):
    self.db = None
    self.db_url = db_url

  def create(self):
    logger.info("database is created")
    self.db = Db(self.db_url, "root db creation")

  def close(self):
    logger.info("database is closed")
    self.db.close()

  def clone(self):
    logger.info("Cloning from root database connection")
    new_sql_executor    = sql_executor(self.db_url)
    new_sql_executor.db = self.db.clone("clone db creation")

    return new_sql_executor

class sql_executor_pool:
  def __init__(self):
    self.idx           = 0
    self.sql_executors = []

  def create_executors(self, src_sql_executor, size):
    self.sql_executors.clear()

    assert size > 0, "size > 0"

    for i in range(size):
      self.sql_executors.append(src_sql_executor.clone())

  def get_item(self):
    assert len(self.sql_executors) > 0, "len(self.sql_executors) > 0"

    _current_idx  = self.idx
    self.idx           += 1
    if self.idx == len(self.sql_executors):
      self.idx = 0

    assert self.idx < len(self.sql_executors), "self.idx < len(self.sql_executors)"

    return self.sql_executors[_current_idx]

  def size(self):
    result = ''
    for item in self.sql_executors:
      result += ' ' + item.size()
    return result

  def close(self):
    for item in self.sql_executors:
      if item is not None:
        item.close()

class ServerManager:
  def __init__(self, db_url):
    self.threads      = 1
    self.sql_executor = sql_executor(db_url)
    self.sql_pool     = sql_executor_pool()

    self.receive_thread_executor = None

  def __enter__(self):
    logger.info("enter into server manager")

    if self.sql_executor is not None:
      self.sql_executor.create()

    self.sql_pool.create_executors(self.sql_executor, self.threads)
    self.receive_thread_executor = ThreadPoolExecutor(max_workers = self.threads)

    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    logger.info("exit from server manager")
    if self.sql_executor is not None:
      self.sql_executor.close()

    if self.sql_pool is not None:
      self.sql_pool.close()

class DBHandler(BaseHTTPRequestHandler):
  def __init__(self, methods, db_server, *args, **kwargs):
      self.methods = methods
      self.db_server = db_server
      super().__init__(*args, **kwargs)

  @staticmethod
  def decimal_serialize(obj):
      return simplejson.dumps(obj=obj, use_decimal=True, default=vars)

  @staticmethod
  def decimal_deserialize(s):
      return simplejson.loads(s=s, use_decimal=True)

  def send(self, clone_sql_executor, request):
    ctx = {
      "db": clone_sql_executor.db,
      "id": json.loads(request)['id'] # TODO: remove this if additional logging is not required
    }
    response = dispatch(request, methods=self.methods, debug=True, context=ctx, serialize=DBHandler.decimal_serialize, deserialize=DBHandler.decimal_deserialize)

    _response = DBHandler.decimal_serialize(response)
    self.wfile.write(_response.encode())

  def do_POST(self):
    try:
      request = self.rfile.read(int(self.headers["Content-Length"])).decode()
      logger.info(request)

      _future = self.db_server.receive_thread_executor.submit(self.send, self.db_server.sql_pool.get_item(), request)

      _future.result()

    except Exception as ex:
      logger.error("Exception in POST method: {0}".format(ex))
      self.send_response(500)

def run_server(db_url, port):
  with ServerManager(db_url) as mgr:

    methods = APIMethods.build_methods()
    handler = partial(DBHandler, methods, mgr)

    http_server = HTTPServer(('', port), handler)
    http_server.serve_forever()
