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
from jsonrpcserver import async_dispatch as dispatch

from ah.api.endpoints import build_methods as account_history

import simplejson
from ah.server.db import Db

# pylint: disable=too-many-lines

def decimal_serialize(obj):
    return simplejson.dumps(obj=obj, use_decimal=True, default=vars)

def decimal_deserialize(s):
    return simplejson.loads(s=s, use_decimal=True)

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
    """Configure and launch the API server."""

    log = logging.getLogger(__name__)
    methods = build_methods()

    app = web.Application()
    app['config'] = dict()
    app['config']['hive.MAX_DB_ROW_RESULTS'] = 100000

    async def init_db(app):
        """Initialize db adapter."""
        app['db'] = await Db.create(db_url)

    async def close_db(app):
        """Teardown db adapter."""
        app['db'].close()
        await app['db'].wait_closed()

    app.on_startup.append(init_db)
    app.on_cleanup.append(close_db)

    async def jsonrpc_handler(request):
        """Handles all hive jsonrpc API requests."""
        t_start = perf_counter()
        request = await request.text()
        ctx = {
          "db": app["db"],
          "id": json.loads(request)['id'] # TODO: remove this if additional logging is not required
        }
        # debug=True refs https://github.com/bcb/jsonrpcserver/issues/71
        response = None
        try:
            response = await dispatch(request, methods=methods, debug=True, context=ctx, serialize=decimal_serialize, deserialize=decimal_deserialize)
        except Exception as ex:
            # first log exception
            # TODO: consider removing this log - potential log spam
            log.exception(ex)
            exc_type, exc_value, exc_traceback = sys.exc_info()
            print("*** print_tb:")
            traceback.print_tb(exc_traceback, limit=1000, file=sys.stdout)

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
            headers = {
                'Access-Control-Allow-Origin': '*'
            }
            
            return web.json_response(error_response, status=200, headers=headers, dumps=decimal_serialize)

        if response is not None and response.wanted:
            headers = {
                'Access-Control-Allow-Origin': '*'
            }
            ret = web.json_response(response.deserialized(), status=200, headers=headers, dumps=decimal_serialize)
            return ret
        ret = web.Response()
        return ret

    app.router.add_post('/', jsonrpc_handler)
    web.run_app(app, port=port)
