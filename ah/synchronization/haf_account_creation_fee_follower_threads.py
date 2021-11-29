#!/usr/bin/python3

#Storing all changes of account creation fee

import os
import json
import re

from haf_utilities import helper, range_type
from haf_base import application

from haf_account_creation_fee_follower import callback_handler_account_creation_fee_follower

from concurrent.futures import ThreadPoolExecutor, as_completed

class callback_handler_account_creation_fee_follower_threads(callback_handler_account_creation_fee_follower):

  def __init__(self, threads, schema_name):

    super().__init__(schema_name)
    self.threads  = threads

  def pre_none_ctx(self):
    super().pre_none_ctx()

  def pre_is_ctx(self):
    super().pre_is_ctx()

  def pre_always(self):
    super().pre_always()

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

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _ranges = self.prepare_ranges(low_block, high_block, self.threads)

    _futures = []
    with ThreadPoolExecutor(max_workers=len(_ranges)) as executor:
      for range in _ranges:
        helper.info("new thread created for a range: {}:{}", range.low, range.high)
        _futures.append(executor.submit(super().run_impl, range.low, range.high))

    for future in as_completed(_futures):
      future.result()

  def post(self): 
    super().post()

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

  _schema_name = "fee_follower_threads"

  _callbacks      = callback_handler_account_creation_fee_follower_threads(_threads, _schema_name)
  _app            = application(_url, _range_blocks, _schema_name + "_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
