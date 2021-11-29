import sys
import logging

from signal import signal, SIGINT, SIGTERM

from collections import deque

from haf_sql import haf_sql
from haf_utilities import range_type, args_container, helper, timer

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

    helper.logger = logger

  def interrupt(self):
    if not self.is_interrupted():
      self.interrupted = True

  def is_interrupted(self):
    _result = self.interrupted
    if _result:
      helper.info("An application has been interrupted")
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
      helper.error("`preprocess` method exception: {0}", ex)
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
            helper.info("Values in range blocks have NULL")
            return None, None
          else:
            _first_block  = int(_record[0])
            _last_block   = int(_record[1])

          helper.info("first block: {} last block: {}", _first_block, _last_block)
          return _first_block, _last_block
        else:
          helper.info("Range blocks is returned empty")
          return None, None
    except Exception as ex:
      helper.error("`get_blocks` method exception: {0}", ex)
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
      helper.error("`fill_block_ranges` method exception: {0}", ex)
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
      helper.error("`work` method exception: {0}", ex)
      self.raise_exception(ex)

  def run_impl(self):
    try:
      with timer("TOTAL RUN-IMPL[ms]: {}") as tm:
        if self.is_interrupted():
          return False

        _first_block, _last_block = self.get_blocks()
        if _first_block is None:
          return True

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
      helper.error("`run_impl` method exception: {0}", ex)
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
      helper.error("`postprocess` method exception: {0}", ex)
      self.raise_exception(ex)

  def run(self):
    with timer("TOTAL RUN[ms]: {}") as tm:
      try:
        _result = self.preprocess()
        if not _result:
          return False

        while True:
          if not self.run_impl():
            break

        _result = self.postprocess()
        if not _result:
          return False
      except Exception as ex:
        helper.error("`run` method exception: {0}", ex)
        self.raise_exception(ex)

def shutdown_properly(signal, frame):
  helper.info("Closing. Wait...")

  global app
  assert app is not None, "an application must be initialized"
  app.interrupt()

  helper.info("Interrupted...")

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

class application:
  def __init__(self, url, range_blocks, app_context, callback_handler):
    self.url              =  url
    self.range_blocks     =  range_blocks
    self.app_context      = app_context
    self.callback_handler = callback_handler
    self.base             = haf_base()

  def exec_query(self, query, **kwargs):
    assert self.base is not None
    self.base.sql.exec_query(query, **kwargs)

  def exec_query_all(self, query, **kwargs):
    assert self.base is not None
    return self.base.sql.exec_query_all(query, **kwargs)

  def exec_query_one(self, query, **kwargs):
    assert self.base is not None
    return self.base.sql.exec_query_one(query, **kwargs)

  def process(self):
    try:
      with timer("TOTAL APPLICATION TIME[ms]: {}") as tm:

        set_handlers()

        helper.args   = args_container(self.url, self.range_blocks)

        self.base           = haf_base()
        self.base.sql       = haf_sql(self.app_context)
        self.base.callbacks = self.callback_handler

        result = self.base.run()

        restore_handlers()

    except Exception as ex:
      helper.error("`process` method exception: {0}", ex)
      exit(1)
