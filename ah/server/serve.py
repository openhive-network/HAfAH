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

from socketserver import ForkingMixIn

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

nr_threads = 10

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

class ServerManager:
  def __init__(self, db_url):
    self.db_url       = db_url
    self.sql_executor = sql_executor(self.db_url)

  def __enter__(self):
    logger.info("enter into server manager")

    if self.sql_executor is not None:
      self.sql_executor.create()

    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    logger.info("exit from server manager")
    if self.sql_executor is not None:
      self.sql_executor.close()

class ForkHTTPServer(ForkingMixIn, HTTPServer):
    pass

class ProcessData:
  sql_executor = {}
  def __init__(self):
    pass

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

  def send(self, request):
    try:

      _id = os.getpid()

      _sql_executor = None

      logger.info( "methods: is {}".format(self.methods) )

      if _id in ProcessData.sql_executor:
        logger.info( "process: is {}".format(os.getpid()) )
        _sql_executor = ProcessData.sql_executor[_id]
      else:
        logger.info( "process: no {} {}".format(os.getpid(), self.db_server.db_url) )
        _sql_executor = sql_executor(self.db_server.db_url)
        _sql_executor.create()
        ProcessData.sql_executor[_id] = _sql_executor

      assert _sql_executor.db is not None, "lack of database"
      ctx = {
        "db": _sql_executor.db,
        "id": json.loads(request)['id'] # TODO: remove this if additional logging is not required
      }
      response = dispatch(request, methods=self.methods, debug=True, context=ctx, serialize=DBHandler.decimal_serialize, deserialize=DBHandler.decimal_deserialize)

      self.send_response(200)
      self.send_header("Content-type", "application/json")
      self.end_headers()
      self.wfile.write(str(response).encode())

    except Exception as ex:
      logger.info(ex)

  def do_POST(self):
    try:
      request = self.rfile.read(int(self.headers["Content-Length"])).decode()
      logger.info(request)
      self.send(request)

    except Exception as ex:
      logger.error("Exception in POST method: {0}".format(ex))
      self.send_response(500)

def run_server(db_url, port):
  with ServerManager(db_url) as mgr:

    methods = APIMethods.build_methods()
    handler = partial(DBHandler, methods, mgr)

    http_server = ForkHTTPServer(('', port), handler)
    http_server.serve_forever()
