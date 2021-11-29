#!/usr/bin/python3

#Storing all changes of account creation fee

import os
import json
import re

from haf_utilities import helper
from haf_base import application

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

class callback_handler_account_creation_fee_follower:

  def __init__(self):
    self.logger         = None
    self.app            = None

    #SQL queries
    self.create_history_table = '''
      CREATE SCHEMA IF NOT EXISTS fee_follower;
      CREATE TABLE IF NOT EXISTS fee_follower.fee_history
      (
        block_num INTEGER NOT NULL,
        witness_id INTEGER NOT NULL,
        fee VARCHAR(200) NOT NULL
      )INHERITS( hive.{} );
    '''

    self.insert_into_history = []
    self.insert_into_history.append( "INSERT INTO fee_follower.fee_history(block_num, witness_id, fee) SELECT T.block_num, A.id, T.fee FROM ( VALUES" )
    self.insert_into_history.append( " ( {}, '{}', {} )" )
    self.insert_into_history.append( " ) T(block_num, witness_name, fee) JOIN hive.fee_follower_app_accounts_view A ON T.witness_name = A.name;" )

    self.get_witness_updates = '''
      SELECT block_num, body
      FROM hive.fee_follower_app_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::witness_update_operation' AND block_num >= {} and block_num <= {}
    '''

  def checker(self):
    assert self.logger is not None, "a logger must be initialized"
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    self.checker()
    _result = self.app.exec_query(self.create_history_table.format(self.app.app_context))
    self.logger.info("Nothing to do: *****PRE-NONE-CTX*****")

  def pre_is_ctx(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-IS-CTX*****")

  def pre_always(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-ALWAYS*****")

  def run(self, low_block, high_block):
    self.checker()

    _query = self.get_witness_updates.format(low_block, high_block)
    _result = self.app.exec_query_all(_query)

    _values = []
    self.logger.info("For blocks {}:{} found {} witness updates".format(low_block, high_block, len(_result)))

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
  
  def post(self): 
    self.checker()
    self.logger.info("Nothing to do: *****POST*****")

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000
  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks

def main():

  _url, _range_blocks = process_arguments()

  _callbacks      = callback_handler_account_creation_fee_follower()
  _app            = application(_url, _range_blocks, "fee_follower_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
