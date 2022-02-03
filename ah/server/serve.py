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

from ah.utils.performance import perf

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

def request_extractor(request) -> dict:
  # "method": parsed_req['method'].split('.')[-1].strip()
  parsed_req = json.loads(request)
  return {"id": parsed_req['id']}


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
    self.db_url = db_url
    self.db     = None

  def __enter__(self):
    self.db = Db(self.db_url, "db creation")
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    self.db.close()

class ForkHTTPServer(ForkingMixIn, HTTPServer):
    pass

class DBHandler(BaseHTTPRequestHandler):
  def __init__(self, methods, db_url, log_responses, *args, **kwargs):
      self.methods        = methods
      self.db_url         = db_url
      self.log_responses  = log_responses
      super().__init__(*args, **kwargs)

  @staticmethod
  def decimal_serialize(obj):
      return simplejson.dumps(obj=obj, use_decimal=True, default=vars, ensure_ascii=False, encoding='utf8')

  @staticmethod
  def decimal_deserialize(s):
      return simplejson.loads(s=s, use_decimal=True)

  def send_reponse(self, http_code, content_type, response):
    self.send_response(http_code)
    self.send_header("Content-type", content_type)
    self.end_headers()
    self.wfile.write(str(response).encode())

  def log_request(self, *args, **kwargs) -> None:
    # return super().log_request(code=code, size=size)
    pass

  @perf(extract_identifier=lambda _, kwargs: kwargs['id'])
  def process_request(self, request, **ctx):
    try:
      with sql_executor(self.db_url) as _sql_executor:

        assert _sql_executor.db is not None, "lack of database"
        ctx['db'] = _sql_executor.db.clone('')

        _response = dispatch(request, methods=self.methods, debug=True, context=ctx, serialize=DBHandler.decimal_serialize, deserialize=DBHandler.decimal_deserialize)

        if self.log_responses:
          logger.info(_response)

        self.send_reponse(200, "application/json", _response)

    except Exception as ex:
      logger.error(ex)
      self.send_reponse(500, "text/html", ex)

  def do_POST(self):
    try:
      request = self.rfile.read(int(self.headers["Content-Length"])).decode()
      self.process_request(request, **request_extractor(request))

    except Exception as ex:
      logger.error(ex)
      self.send_reponse(500, "text/html", ex)

class PreparationPhase:
  def __init__(self, db_url, sql_src_path):
    self.db_url       = db_url
    self.sql_src_path = sql_src_path

  def read_file(self):
    with open(self.sql_src_path, 'r') as file:
      return file.read()
    return ""

  def prepare_server(self):
    logger.info("preparation of http server - loading SQL functions into a database")

    try:
      with sql_executor(self.db_url) as _sql_executor:
        assert _sql_executor.db is not None, "lack of database"

        _query = self.read_file()
        if len(_query) > 0:
          _sql_executor.db.query_no_return(_query)

        logger.info("http server is prepared")
        return True
    except Exception as ex:
      logger.error(ex)
      logger.info("an error occurred during http server preparation")
      return False

def run_server(db_url, port, log_responses, sql_src_path):
  _prep_phase = PreparationPhase(db_url, sql_src_path)
  if not _prep_phase.prepare_server():
    return

  logger.info("connecting into http server")

  methods = APIMethods.build_methods()
  handler = partial(DBHandler, methods, db_url, log_responses)

  http_server = ForkHTTPServer(('0.0.0.0', port), handler)

  logger.info("http server is connected")
  http_server.serve_forever()
