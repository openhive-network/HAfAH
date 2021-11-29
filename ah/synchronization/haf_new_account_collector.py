#!/usr/bin/python3

#Getting data [block_number;creator;new_account]

import os
import json

from haf_utilities import helper
from haf_base import application

class callback_handler_accounts:
  
  def __init__(self):
    self.app    = None

    #SQL queries
    self.create_creator_account_table = '''
      CREATE SCHEMA IF NOT EXISTS new_accounts;
      CREATE TABLE IF NOT EXISTS new_accounts.creation_history
      (
        block_num INTEGER NOT NULL,
        creator_id INTEGER DEFAULT NULL,
        account_id INTEGER NOT NULL
      );
    '''

    self.get_accounts = '''
      SELECT block_num, body
      FROM hive.new_accounts_app_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::account_created_operation' AND block_num >= {} and block_num <= {}
    '''

    self.insert_into_history = []
    self.insert_into_history.append( "INSERT INTO new_accounts.creation_history(block_num, creator_id, account_id) SELECT T.block_num, C.id, A.id FROM ( VALUES" )
    self.insert_into_history.append( " ( {}, '{}', '{}' )" )
    self.insert_into_history.append( '''
      ) T(block_num, creator, new_account)
      LEFT JOIN hive.new_accounts_app_accounts_view C ON T.creator = C.name
      JOIN hive.new_accounts_app_accounts_view A ON T.new_account = A.name
    ''' )

  def checker(self):
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    helper.info("Creation SQL tables: (PRE-NON-CTX phase)")
    self.checker()
    _result = self.app.exec_query(self.create_creator_account_table)

  def pre_is_ctx(self):
    pass

  def pre_always(self):
    pass

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _query = self.get_accounts.format(low_block, high_block)
    _result = self.app.exec_query_all(_query)

    helper.info("For blocks {}:{} found {} new accounts".format(low_block, high_block, len(_result)))

    _values = []
    for record in _result:
      _op = json.loads(record[1])

      _new_account_name = None
      _creator          = None

      if 'value' in _op:
        _value = _op['value']
        if 'new_account_name' in _value:
          _new_account_name = _value['new_account_name']
          if 'creator' in _value:
            _creator = _value['creator']
            _values.append(self.insert_into_history[1].format(record[0], _creator, _new_account_name))

    helper.execute_complex_query(self.app, _values, self.insert_into_history)

  def post(self): 
    pass

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000
  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks

def main():

  _url, _range_blocks= process_arguments()

  _callbacks      = callback_handler_accounts()
  _app            = application(_url, _range_blocks, "new_accounts_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
