#!/usr/bin/python3

#Storing all changes of account creation fee

import os
import json
import re

from haf_utilities import helper, range_type
from haf_base import application

from concurrent.futures import ThreadPoolExecutor, as_completed

# convert special chars into their octal formats recognized by sql
SPECIAL_CHARS = {
    "\x00" : " ", # nul char cannot be stored in string column (ABW: if we ever find the need to store nul chars we'll need bytea, not text)
    "\r" : "\\015",
    "\n" : "\\012",
    "\v" : "\\013",
    "\f" : "\\014",
    "\\" : "\\134",
    "'" : "\\047",
    "%" : "\\045",
    "_" : "\\137",
    ":" : "\\072"
}

def escape_characters(text):
    """ Escape special charactes """
    assert isinstance(text, str), "Expected string got: {}".format(type(text))
    if len(text.strip()) == 0:
        return "'" + text + "'"

    ret = "E'"

    for ch in text:
        if ch in SPECIAL_CHARS:
            dw = SPECIAL_CHARS[ch]
            ret = ret + dw
        else:
            ordinal = ord(ch)
            if ordinal <= 0x80 and ch.isprintable():
                ret = ret + ch
            else:
                hexstr = hex(ordinal)[2:]
                i = len(hexstr)
                max = 4
                escaped_value = '\\u'
                if i > max:
                    max = 8
                    escaped_value = '\\U'
                while i < max:
                    escaped_value += '0'
                    i += 1
                escaped_value += hexstr
                ret = ret + escaped_value

    ret = ret + "'"
    return ret

class callback_handler_account_creation_fee_follower_threads:

  def __init__(self, threads):
    self.app            = None
    self.threads        = threads

    #SQL queries
    self.create_history_table = '''
      CREATE SCHEMA IF NOT EXISTS fee_follower_threads;
      CREATE TABLE IF NOT EXISTS fee_follower_threads.fee_history
      (
        block_num INTEGER NOT NULL,
        witness_id INTEGER NOT NULL,
        fee VARCHAR(200) NOT NULL
      )INHERITS( hive.{} );
    '''

    self.insert_into_history = []
    self.insert_into_history.append( "INSERT INTO fee_follower_threads.fee_history(block_num, witness_id, fee) SELECT T.block_num, A.id, T.fee FROM ( VALUES" )
    self.insert_into_history.append( " ( {}, '{}', {} )" )
    self.insert_into_history.append( " ) T(block_num, witness_name, fee) JOIN hive.fee_follower_threads_app_accounts_view A ON T.witness_name = A.name;" )

    self.get_witness_updates = '''
      SELECT block_num, body
      FROM hive.fee_follower_threads_app_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::witness_update_operation' AND block_num >= {} and block_num <= {}
    '''

  def checker(self):
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    helper.info("Creation SQL tables: (PRE-NON-CTX phase)")
    self.checker()
    _result = self.app.exec_query(self.create_history_table.format(self.app.app_context))

  def pre_is_ctx(self):
    pass

  def pre_always(self):
    pass

  def prepare_ranges(self, low_value, high_value, threads):
    assert threads > 0 and threads <= 64, "threads > 0 and threads <= 64"

    if threads == 1:
      return [ range_type(low_value, high_value) ]

    #It's better to send small amount of data in only 1 thread. More threads introduce unnecessary complexity.
    #Beside, if (high_value - low_value) < threads, it's impossible to spread data amongst threads in reasonable way.
    _thread_threshold = 500
    if high_value - low_value + 1 <= _thread_threshold:
      return [ range_type(low_value, high_value) ]

    _ranges = []
    _size = int(( high_value - low_value + 1 ) / threads)

    for i in range(threads):
      if i == 0:
        _ranges.append(range_type(low_value, low_value + _size))
      else:
        _low = _ranges[i - 1].high + 1
        _ranges.append(range_type(_low, _low + _size))

    assert len(_ranges) > 0
    _ranges[len(_ranges) - 1].high = high_value

    return _ranges

  def run_in_thread(self, low_block, high_block):
    _query = self.get_witness_updates.format(low_block, high_block)
    _result = self.app.exec_query_all(_query)

    _values = []
    helper.info("For blocks {}:{} found {} witness updates", low_block, high_block, len(_result))

    for record in _result:
      _op = json.loads(record[1])

      if 'value' in _op:
        _value = _op['value']

      _owner                = None
      _account_creation_fee = None

      if 'owner' in _value:
        _owner = _value['owner']
        if 'props' in _value and 'account_creation_fee' in _value['props']:
          _account_creation_fee = _op['value']['props']['account_creation_fee']

      if _owner is not None and _account_creation_fee is not None:
        __account_creation_fee = escape_characters(json.dumps(_account_creation_fee))
        _values.append(self.insert_into_history[1].format(record[0], _owner, __account_creation_fee))

    helper.execute_complex_query(self.app, _values, self.insert_into_history)

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _ranges = self.prepare_ranges(low_block, high_block, self.threads)

    _futures = []
    with ThreadPoolExecutor(max_workers=len(_ranges)) as executor:
      for range in _ranges:
        helper.info("new thread created for a range: {}:{}", range.low, range.high)
        _futures.append(executor.submit(self.run_in_thread, range.low, range.high))

    for future in as_completed(_futures):
      future.result()

  def post(self): 
    pass

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000
  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")
  parser.add_argument("--threads", type = int, default = 2, help = "Number of threads used for processing")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks, _args.threads

def main():

  _url, _range_blocks, _threads = process_arguments()

  _callbacks      = callback_handler_account_creation_fee_follower_threads(_threads)
  _app            = application(_url, _range_blocks, "fee_follower_threads_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
