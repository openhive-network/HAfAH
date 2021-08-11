#!/usr/bin/python3

from json import loads
from json.decoder import JSONDecodeError
from aiohttp import web
from aiohttp.web_app import Application
from aiohttp.web_request import Request
from jsonrpcserver.response import Response
from ah.api.endpoints import *
from aiohttp.web import json_response
from ah.api.objects import result

psql_conn_str = "postgresql://postgres:pass@127.0.0.1:5432/hafah"
ah_singleton = backend_singleton(psql_conn_str)
methods = build_methods()

def json_encoder( obj ):
  from json import dumps
  return dumps( obj, default=vars )

def build_response( obj, id ):
  return json_response( vars(result(obj, id)), dumps=json_encoder )

def build_error_message(message : str, data : str, status : int) -> Response:
  return json_response({
      "jsonrpc":"2.0",
      "error" : {
          "code": -32602,
          "data": data,
          "message": message
      },
      "id" : -1
    },
    headers = {
        'Access-Control-Allow-Origin': '*'
    },
    status=status
  )

app = Application()

async def jsonrpc_handler(request : Request):
    try:
      req_as_bin = await request.read()
      req_as_str = req_as_bin.decode('utf-8')
      requ = loads(req_as_str)
      return build_response(await methods[requ['method']]( **requ['params'] ), requ['id'])
    except JSONDecodeError as ex:
      # https://http.cat/406 
      return build_error_message(
        message="Invalid parameters",
        data="Invalid JSON in request: " + str(ex),
        status=406
      )
    except Exception as ex:
      return build_error_message(
        message="Unknown exception",
        data="Details: " + str(ex),
        status=500
      )

app.router.add_post('/', jsonrpc_handler)
web.run_app(app, port=8090)
