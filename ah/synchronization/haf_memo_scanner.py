#!/usr/bin/python3

#Storing all transfers that were detected as memo

import os
import json
import re

from haf_utilities import helper
from haf_base import application

class callback_handler_memo_scanner:

  def __init__(self, searched_item):
    self.logger         = None
    self.app            = None
    self.searched_item  = searched_item

    #SQL queries
    self.create_memo_table = '''
      CREATE SCHEMA IF NOT EXISTS memo_scanner;
      CREATE TABLE IF NOT EXISTS memo_scanner.memos (
        block_num INTEGER NOT NULL,
        trx_in_block INTEGER NOT NULL,
        op_pos INTEGER NOT NULL,
        memo_content VARCHAR(512) NOT NULL
      )INHERITS( hive.memo_scanner_app );

      ALTER TABLE memo_scanner.memos ADD CONSTRAINT memos_pkey PRIMARY KEY ( block_num, trx_in_block, op_pos );
    '''

    self.insert_into_memos             = []
    self.insert_into_memos.append( "INSERT INTO memo_scanner.memos(block_num, trx_in_block, op_pos, memo_content) VALUES" )
    self.insert_into_memos.append( " ({}, {}, {}, '{}')" )
    self.insert_into_memos.append( " ;" )

    self.get_transfers = '''
      SELECT block_num, trx_in_block, op_pos, body
      FROM hive.operations o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::transfer_operation' AND block_num >= {} and block_num <= {}
    '''

  def checker(self):
    assert self.logger is not None, "a logger must be initialized"
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    self.checker()
    _result = self.app.exec_query(self.create_memo_table)
    self.logger.info("Nothing to do: *****PRE-NONE-CTX*****")

  def pre_is_ctx(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-IS-CTX*****")

  def pre_always(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-ALWAYS*****")

  def run(self, low_block, high_block):
    self.checker()

    _query = self.get_transfers.format(low_block, high_block)
    _result = self.app.exec_query_all(_query)

    _values = []
    self.logger.info("For blocks {}:{} found {} transfers".format(low_block, high_block, len(_result)))
    for record in _result:
      _op = json.loads(record[3])
      if 'value' in _op and 'memo' in _op['value']:
        _memo = _op['value']['memo']

        if re.search(self.searched_item, _memo, re.IGNORECASE) is not None:
          _values.append(self.insert_into_memos[1].format(record[0], record[1], record[2], _memo))

    helper.execute_complex_query(self.app, _values, self.insert_into_memos)
  
  def post(self):
    self.checker()
    self.logger.info("Nothing to do: *****POST*****")

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000
  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")
  parser.add_argument("--searched-item", type = str, required = True, help = "Part of memo that should be found")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks, _args.searched_item

def main():

  _url, _range_blocks, searched_item = process_arguments()

  _callbacks      = callback_handler_memo_scanner(searched_item)
  _app            = application(_url, _range_blocks, "memo_scanner_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
