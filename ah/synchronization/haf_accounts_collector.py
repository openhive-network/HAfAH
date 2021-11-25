#!/usr/bin/python3

from haf_utilities import callback_handler
from haf_base import db_processor

class callback_handler_accounts:

  def __init__(self):
    self.logger = None

  def pre_none_ctx(self):
    print("sssssssssssssssssss", flush=True)
    self.logger.info("*********************************************************************PRE-NONE-CTX")

  def pre_is_ctx(self):
    self.logger.info("*********************************************************************PRE-IS-CTX")

  def pre_always(self):
    self.logger.info("*********************************************************************PRE-ALWAYS")

  def run(self, low_block, high_block):
    self.logger.info("*********************************************************************RUN {} {}".format(low_block, high_block))

  def post(self):
    self.logger.info("*********************************************************************POST")

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

  _callbacks    = callback_handler_accounts()

  _db_processor = db_processor(_url, _range_blocks, "all_accounts_app", _callbacks)
  _db_processor.process()

if __name__ == '__main__':
  main()