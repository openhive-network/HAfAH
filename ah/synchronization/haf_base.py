#!/usr/bin/python3
import sys
import logging

from signal import signal, SIGINT, SIGTERM

from collections import deque

from haf_sql import haf_sql
from haf_utilities import range_type, args_container, helper, callback_handler, timer

LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"
MAIN_LOG_PATH = "haf-base.log"

MODULE_NAME = "HAF-TEMPLATE"
logger = logging.getLogger(MODULE_NAME)
logger.setLevel(LOG_LEVEL)

ch = logging.StreamHandler(sys.stdout)
ch.setLevel(LOG_LEVEL)
ch.setFormatter(logging.Formatter(LOG_FORMAT))

fh = logging.FileHandler(MAIN_LOG_PATH)
fh.setLevel(LOG_LEVEL)
fh.setFormatter(logging.Formatter(LOG_FORMAT))

if not logger.hasHandlers():
  logger.addHandler(ch)
  logger.addHandler(fh)

class haf_base:
  def __init__(self, sql = None, callbacks = None):
    self.interrupted    = False
    self.is_massive     = False

    self.last_block_num = 0

    self.block_ranges   = deque()

    self.sql            = sql
    self.callbacks      = callbacks

  def interrupt(self):
    if not self.is_interrupted():
      self.interrupted = True

  def is_interrupted(self):
    _result = self.interrupted
    if _result:
      helper.logger.info("An application has been interrupted")
    return _result

  def preprocess(self):
    with timer("TOTAL PREPROCESS[ms]: {}") as tm:
      if self.is_interrupted():
        return False

      if not self.sql.exec_exists_context():
        self.sql.exec_create_context()

        if self.callbacks is not None and self.callbacks.pre_none_ctx is not None:
          self.callbacks.pre_none_ctx()
      else:
        if self.callbacks is not None and self.callbacks.pre_is_ctx is not None:
          self.callbacks.pre_is_ctx()

      if self.callbacks is not None and self.callbacks.pre_always is not None:
        self.callbacks.pre_always()
      return True

  def get_blocks(self):
    with timer("TOTAL GET BLOCKS[ms]: {}") as tm:
      if self.is_interrupted():
        return None, None

      _first_block = 0
      _last_block  = 0

      self.sql.attach_context()
      _range_blocks = self.sql.exec_next_block()

      if _range_blocks is not None and len(_range_blocks) > 0:
        assert len(_range_blocks) == 1

        _record = _range_blocks[0]

        if _record[0] is None or _record[1] is None:
          logger.info("Values in range blocks have NULL")
          return None, None
        else:
          _first_block  = int(_record[0])
          _last_block   = int(_record[1])

        helper.logger.info("first block: {} last block: {}".format(_first_block, _last_block))
        return _first_block, _last_block
      else:
        helper.logger.info("Range blocks is returned empty")
        return None, None

  def fill_block_ranges(self, first_block, last_block):
    with timer("TOTAL FILLING BLOCKS[ms]: {}") as tm:
      if self.is_interrupted():
        return False

      if first_block == last_block:
        self.block_ranges.append(range_type(first_block, last_block))
        return True

      _last_block = first_block

      while _last_block != last_block:
        _last_block = min(_last_block + helper.args.range_blocks, last_block)
        self.block_ranges.append(range_type(first_block, _last_block))
        first_block = _last_block + 1

      return True

  def work(self):
    with timer("TOTAL WORK[ms]: {}") as tm:
      if self.is_interrupted():
        return False

      while len(self.block_ranges) > 0:
        if self.is_interrupted():
          return False

        _item = self.block_ranges.popleft()

        if self.callbacks is not None and self.callbacks.run is not None:
          self.callbacks.run(_item.low, _item.high)

        self.last_block_num = _item.high

        if self.is_massive and self.last_block_num is not None:
          self.sql.exec_context_detached_save_block_num(self.last_block_num)

      return True

  def run_impl(self):
    with timer("TOTAL RUN-IMPL[ms]: {}") as tm:
      if self.is_interrupted():
        return False

      _first_block, _last_block = self.get_blocks()
      if _first_block is None:
        return False

      self.fill_block_ranges(_first_block, _last_block)

      self.is_massive = _last_block - _first_block > 0

      if self.is_massive:
        self.sql.detach_context()

        self.work()

        self.sql.attach_context(self.last_block_num if (self.last_block_num is not None) else 0)
      else:
        self.work()

      return True

  def postprocess(self):
    with timer("TOTAL POSTPROCESS[ms]: {}") as tm:
      if self.is_interrupted():
        return False

      if self.callbacks is not None and self.callbacks.post is not None:
        self.callbacks.post()

      return True

  def run(self):
    with timer("TOTAL RUN[ms]: {}") as tm:
      try:
        _result = self.preprocess()
        if not _result:
          return False

        while True:
          if not self.run_impl():
            return False

        _result = self.postprocess()
        if not result:
          return False
      except Exception as ex:
        logger.error("`main` method exception: {0}".format(ex))
        exit(1)

helper.logger = logger
app           = haf_base()

def shutdown_properly(signal, frame):
  logger.info("Closing. Wait...")

  global app
  app.interrupt()

  logger.info("Interrupted...")

old_sig_int_handler = None
old_sig_term_handler = None

def set_handlers():
  global old_sig_int_handler
  global old_sig_term_handler
  old_sig_int_handler = signal(SIGINT, shutdown_properly)
  old_sig_term_handler = signal(SIGTERM, shutdown_properly)

def restore_handlers():
  signal(SIGINT, old_sig_int_handler)
  signal(SIGTERM, old_sig_term_handler)

def process_arguments():
  import argparse
  parser = argparse.ArgumentParser()

  #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000

  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")

  _args = parser.parse_args()

  return _args.url, _args.range_blocks

def pre_none_ctx_test():
  helper.logger.info("*********************************************************************PRE-NONE-CTX")

def pre_is_ctx_test():
  helper.logger.info("*********************************************************************PRE-IS-CTX")

def pre_always_test():
  helper.logger.info("*********************************************************************PRE-ALWAYS")

def run_test(low_block, high_block):
  helper.logger.info("*********************************************************************RUN {} {}".format(low_block, high_block))

def post_test():
  helper.logger.info("*********************************************************************POST")

def main():
  try:
    with timer("TOTAL APPLICATION TIME[ms]: {}") as tm:
      global app
      _app_context = "any_app"

      set_handlers()

      _url, _range_blocks = process_arguments()

      helper.args     = args_container(_url, _range_blocks)

      _sql        = haf_sql(_app_context)
      _callbacks  = callback_handler(pre_none_ctx_test, pre_is_ctx_test, pre_always_test, run_test, post_test)

      app.sql       = _sql
      app.callbacks = _callbacks

      result = app.run()

      restore_handlers()

  except Exception as ex:
    logger.error("`main` method exception: {0}".format(ex))
    exit(1)

if __name__ == '__main__':
  main()
