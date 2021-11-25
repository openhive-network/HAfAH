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

app = None

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

  def raise_exception(self, source_exception):
    self.interrupt()
    raise source_exception

  def preprocess(self):
    try:
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
    except Exception as ex:
      logger.error("`preprocess` method exception: {0}".format(ex))
      self.raise_exception(ex)

  def get_blocks(self):
    try:
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
    except Exception as ex:
      logger.error("`get_blocks` method exception: {0}".format(ex))
      self.raise_exception(ex)

  def fill_block_ranges(self, first_block, last_block):
    try:
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
    except Exception as ex:
      logger.error("`fill_block_ranges` method exception: {0}".format(ex))
      self.raise_exception(ex)

  def work(self):
    try:
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
    except Exception as ex:
      logger.error("`work` method exception: {0}".format(ex))
      self.raise_exception(ex)

  def run_impl(self):
    try:
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
    except Exception as ex:
      logger.error("`run_impl` method exception: {0}".format(ex))
      self.raise_exception(ex)

  def postprocess(self):
    try:
      with timer("TOTAL POSTPROCESS[ms]: {}") as tm:
        if self.is_interrupted():
          return False

        if self.callbacks is not None and self.callbacks.post is not None:
          self.callbacks.post()

        return True
    except Exception as ex:
      logger.error("`postprocess` method exception: {0}".format(ex))
      self.raise_exception(ex)

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
        logger.error("`run` method exception: {0}".format(ex))
        self.raise_exception(ex)

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

class db_processor:
  def __init__(self, url, range_blocks, app_context, callback_handler):
    self.url              =  url
    self.range_blocks     =  range_blocks
    self.app_context      = app_context
    self.callback_handler = callback_handler

  def process(self):
    try:
      with timer("TOTAL APPLICATION TIME[ms]: {}") as tm:
        global app

        set_handlers()

        helper.logger = logger
        helper.args     = args_container(self.url, self.range_blocks)

        app           = haf_base()
        app.sql       = haf_sql(self.app_context)
        app.callbacks = self.callback_handler

        if app.callbacks is not None:
          app.callbacks.logger = helper.logger

        result = app.run()

        restore_handlers()

    except Exception as ex:
      logger.error("`process` method exception: {0}".format(ex))
      exit(1)
