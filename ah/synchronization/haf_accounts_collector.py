#!/usr/bin/python3

#Writing all accounts retrieved from a database into given file name.

import os

from haf_utilities import callback_handler
from haf_base import application

class callback_handler_accounts:

  def __init__(self, file_name):
    self.logger = None
    self.app    = None

    self.file_name  = file_name

    #SQL query
    self.get_accounts = "select name from hive.accounts where block_num >= {} and block_num <= {}"

  def checker(self):
    assert self.logger is not None, "a logger must be initialized"
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-NONE-CTX*****")

  def pre_is_ctx(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-IS-CTX*****")

  def pre_always(self):
    self.checker()
    self.logger.info("Nothing to do: *****PRE-ALWAYS*****")

  def run(self, low_block, high_block):
    self.checker()

    _query = self.get_accounts.format(low_block, high_block)
    _result = self.app.exec_query_all(_query)

    self.logger.info("For blocks {}:{} found {} accounts".format(low_block, high_block, len(_result)))
    with open(self.file_name, "a") as f:
      for record in _result:
        f.write('{}\n'.format(record[0]))

  def post(self):
    self.checker()
    self.logger.info("Nothing to do: *****POST*****")

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000 --file-name "test.txt"
  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")
  parser.add_argument("--file-name", type = str, default = "result.txt", help = "A file where all accounts will be saved")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks, _args.file_name

def main():

  _url, _range_blocks, file_name = process_arguments()

  _callbacks      = callback_handler_accounts(file_name)
  _app            = application(_url, _range_blocks, "all_accounts_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
