# -*- coding: utf-8 -*-
"""Hive JSON-RPC API server."""
import json
from functools import partial
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ForkingMixIn

import simplejson
from jsonrpcserver import dispatch
from jsonrpcserver.methods import Methods
from jsonrpcserver.response import Response

from hafah.adapter import Db
from hafah.endpoints import build_methods as account_history
from hafah.logger import get_logger
from hafah.performance import Timer

logger = get_logger(module_name='AH synchronizer')

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

def handler(name, time, self, req, ctx, *_, **__):
  ctx[name] = time

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

  def process_response(self, http_code, content_type, response):
    data = str(response).encode()
    self.send_response(http_code)
    self.send_header("Content-type", content_type)
    self.send_header('Content-length', len(data))
    self.end_headers()
    self.wfile.write(data)

  def log_request(self, *args, **kwargs) -> None:
    # return super().log_request(code=code, size=size)
    pass

  def process_request(self, request, ctx):
    try:
      with sql_executor(self.db_url) as _sql_executor:

        assert _sql_executor.db is not None, "lack of database"
        ctx['db'] = _sql_executor.db

        _response : Response = dispatch(request, methods=self.methods, debug=True, context=ctx, serialize=DBHandler.decimal_serialize, deserialize=DBHandler.decimal_deserialize)
        ctx['id'] = _response.id

        if self.log_responses:
          logger.info(_response)

        self.process_response(200, "application/json", _response)

    except Exception as ex:
      logger.error(ex)
      self.process_response(500, "text/html", ex)

  def do_POST(self):
    ctx = { 'perf' : {}, 'id': None }
    with Timer() as timer:
      try:
        request = self.rfile.read(int(self.headers["Content-Length"])).decode()
        self.process_request(request, ctx)

      except Exception as ex:
        logger.error(ex)
        self.process_response(500, "text/html", ex)

    # logging times
    perf : dict = ctx['perf']
    perf['process_request'] = (timer.time - sum(perf.values()))
    id = json.dumps(ctx['id']).strip('"')
    for key, value in ctx['perf'].items():
      logger.debug(f'[{id}] {key} executed in {value :.2f}ms')

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
  logger.info('configured for endpoints: \n - ' + '\n - '.join(methods.items.keys()))

  handler = partial(DBHandler, methods, db_url, log_responses)
  http_server = ForkHTTPServer(('0.0.0.0', port), handler)

  logger.info("http server is connected")
  http_server.serve_forever()
