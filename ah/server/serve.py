# -*- coding: utf-8 -*-
"""Hive JSON-RPC API server."""
import os
import sys
import logging
import time
import traceback
import json
from socketserver  import ThreadingMixIn
from http.server import BaseHTTPRequestHandler, HTTPServer
# import asyncio
from concurrent.futures import ThreadPoolExecutor
import threading

from time import perf_counter
from sqlalchemy import exc
from sqlalchemy.exc import OperationalError
from aiohttp import web
from jsonrpcserver.methods import Methods
from jsonrpcserver import dispatch
import queue

from ah.api.endpoints import build_methods as account_history

import simplejson
from ah.server.db import Db

# pylint: disable=too-many-lines

app_config = dict()
class PoolMixIn(ThreadingMixIn):
    def process_request(self, request, client_address):
        self.pool.submit(self.process_request_thread, request, client_address)
class PoolHTTPServer(PoolMixIn, HTTPServer):
        pool = ThreadPoolExecutor(max_workers=8)

class Handler(BaseHTTPRequestHandler):

    def do_POST(self):
        # self._process_n=7  # if not set will default to number of CPU cores
        # self._thread_n=8  # if not set will default to number of threads
        methods = build_methods()
        request = self.rfile.read(int(self.headers["Content-Length"])).decode()
        message =  threading.currentThread().getName()
        print(message)    

        ctx = {
            "db": app_config["db"],
            "id": json.loads(request)['id']
        }
        response = None

        try:
            response = dispatch(request, methods=methods, debug=True, context=ctx, serialize=decimal_serialize, deserialize=decimal_deserialize)
        except Exception as ex:
            # create and send error response
            error_response = {
                "jsonrpc":"2.0",
                "error" : {
                    "code": -32602,
                    "data": "Invalid JSON in request: " + str(ex),
                    "message": "Invalid parameters"
                },
                "id" : -1
            }
            
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            error_response = json.dumps(error_response)
            self.wfile.write(json.dumps(error_response).encode('utf-8'))
            return
        
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        response = response.deserialized()
        self.wfile.write(json.dumps(response).encode('utf-8'))
        return


# class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
#     """An HTTP Server that handle requests in a threads"""
#     deamon_threads = True
#     max_workers=40
#     pass

def decimal_serialize(obj):
    return json.dumps(dict(obj))
    # return simplejson.dumps(obj=obj, use_decimal=True, default=vars)

def decimal_deserialize(s):
    return json.loads(dict(s))
    # return simplejson.loads(s=s, use_decimal=True)


async def db_head_state(context):
    return
    """Status/health check."""
    db = context['db']
    sql = ("SELECT num, created_at, extract(epoch from created_at) ts "
           "FROM hive_blocks ORDER BY num DESC LIMIT 1")
    row = await db.query_row(sql)
    return dict(db_head_block=row['num'],
                db_head_time=str(row['created_at']),
                db_head_age=int(time.time() - row['ts']))

def build_methods():
    """Register all supported hive_api/condenser_api.calls."""
    # pylint: disable=expression-not-assigned, line-too-long
    methods = Methods()

    # account_history methods
    methods.add(**account_history())

    return methods

def truncate_response_log(logger):
    """Overwrite jsonrpcserver resp logger to truncate output.

    https://github.com/bcb/jsonrpcserver/issues/65 was one native
    attempt but helps little for more complex response structs.

    See also https://github.com/bcb/jsonrpcserver/issues/73.
    """
    formatter = logging.Formatter('%(levelname)s:%(name)s:%(message).1024s')
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    logger.propagate = False
    logger.addHandler(handler)

def conf_stdout_custom_file_logger(logger, file_name):
    stdout_handler = logging.StreamHandler(sys.stdout)
    file_handler = logging.FileHandler(file_name, 'a', 'utf-8')

    logger.addHandler(stdout_handler)
    logger.addHandler(file_handler)

def run_server(db_url, port):
    """Configure API."""
    app_config['hive.MAX_DB_ROW_RESULTS'] = 100000

    def init_db(app):
        """Initialize db adapter."""
        app['db'] = Db.create(db_url)

    init_db(app_config)

    """Starting threading server."""
    server = PoolHTTPServer(('', port), Handler)
    print('Starting server, use <Ctrl-C> to stop')
    server.serve_forever()