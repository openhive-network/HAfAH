#!/usr/bin/python3

import queue
from collections import deque

import time

import logging
import sys
import datetime
from signal import signal, SIGINT, SIGTERM, getsignal
from concurrent.futures import ThreadPoolExecutor, as_completed


#from db import Db
from adapter import Db

LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"
MAIN_LOG_PATH = "ah.log"

MODULE_NAME = "AH synchronizer"
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

class range_type:
  def __init__(self, low, high):
    self.low  = low
    self.high = high

class account_op:
  def __init__(self, op_id, name):
    self.op_id  = op_id
    self.name   = name

  def __repr__(self):
    return "op_id: {} name: {}".format(self.op_id, self.name)

class account_info:

  next_account_id = 1

  def __init__(self, id, operation_count):
    self.id               = id
    self.operation_count  = operation_count

class ah_query:
  def __init__(self, application_context):

    self.application_context              = application_context

    self.accounts                         = "SELECT id, name FROM hafah_python.accounts;"
    self.account_ops                      = "SELECT ai.name, ai.id, ai.operation_count FROM hafah_python.account_operation_count_info_view ai;"

    self.create_context                   = "SELECT * FROM hive.app_create_context('{}');".format( self.application_context )
    self.detach_context                   = "SELECT * FROM hive.app_context_detach('{}');".format( self.application_context )
    self.attach_context                   = "SELECT * FROM hive.app_context_attach('{}', {});"
    self.check_context                    = "SELECT * FROM hive.app_context_exists('{}');".format( self.application_context )

    self.context_is_attached              = "SELECT * FROM hive.app_context_is_attached('{}')".format( self.application_context )
    self.context_detached_save_block_num  = "SELECT * FROM hive.app_context_detached_save_block_num('{}', {})"
    self.context_detached_get_block_num   = "SELECT * FROM hive.app_context_detached_get_block_num('{}')".format( self.application_context )

    self.next_block                       = "SELECT * FROM hive.app_next_block('{}');".format( self.application_context )

    self.get_bodies                       = """
SELECT ahov.id, hive.get_impacted_accounts(body) as account
FROM
  hive.account_history_python_operations_view ahov
WHERE 
  block_num >= {} AND block_num <= {}
ORDER BY ahov.id
    """

    self.insert_into_accounts             = []
    self.insert_into_accounts.append( "INSERT INTO hafah_python.accounts( id, name ) VALUES" )
    self.insert_into_accounts.append( " ( {}, '{}')" )
    self.insert_into_accounts.append( " ;" )

    self.insert_into_account_ops          = []
    self.insert_into_account_ops.append( "INSERT INTO hafah_python.account_operations( account_id, account_op_seq_no, operation_id ) VALUES" )
    self.insert_into_account_ops.append( " ( {}, {}, {} )" )
    self.insert_into_account_ops.append( " ;" )

class args_container:
  def __init__(self, url = "", schema_dir = "", range_blocks_flush = 1000, threads_receive = 1, threads_send = 1):
    self.url              = url
    self.schema_path      = schema_dir
    self.flush_size       = range_blocks_flush
    self.threads_receive  = threads_receive
    self.threads_send     = threads_send

class singleton(type):
  _instances = {}

  def __call__(cls, *args, **kwargs):
    if cls not in cls._instances:
        instance = super().__call__(*args, **kwargs)
        cls._instances[cls] = instance
    return cls._instances[cls]

class helper:
  @staticmethod
  def get_time(start, end):
    return int((end - start).microseconds / 1000)

  @staticmethod
  def display_query(query):
    if len(query) > 100:
      logger.info("{}...".format(query[0:100]))
    else:
      logger.info("{}".format(query))

class sql_data:
  query  = None
  args   = None

class sql_executor:
  def __init__(self):
    self.db = None

  def init(self):
    logger.info("Initialization of a new database connection")
    self.db = Db(sql_data.args.url, "root db creation")

  def clone(self):
    logger.info("Cloning from root database connection")
    new_sql_executor    = sql_executor()
    new_sql_executor.db = self.db.clone("clone db creation")

    return new_sql_executor

  def perform_query(self, query):
    helper.display_query(query)

    assert self.db is not None, "self.db is not None"

    start = datetime.datetime.now()

    self.db.query_no_return(query)

    end = datetime.datetime.now()
    logger.info("query time[ms]: {}".format(helper.get_time(start, end)))

  def perform_query_all(self, query):
    helper.display_query(query)

    assert self.db is not None, "self.db is not None"

    start = datetime.datetime.now()

    res = self.db.query_all(query)

    end = datetime.datetime.now()
    logger.info("query time[ms]: {}".format(helper.get_time(start, end)))

    return res

  def perform_query_one(self, query):
    helper.display_query(query)

    assert self.db is not None, "self.db is not None"

    start = datetime.datetime.now()

    res = self.db.query_one(query)

    end = datetime.datetime.now()
    logger.info("query time[ms]: {}".format(helper.get_time(start, end)))

    return res

  def receive_impacted_accounts(self, clone_sql_executor, first_block, last_block):
    _items = []

    try:
      logger.info("Receiving impacted accounts: from {} block to {} block".format(first_block, last_block))

      _query  = sql_data.query.get_bodies.format(first_block, last_block)
      _result = clone_sql_executor.perform_query_all(_query)

      if _result is not None and len(_result) != 0:
        logger.info("Found {} operations".format(len(_result)))
        for _record in _result:
          _items.append( account_op( int(_record[0]), str(_record[1]) ) )
    except Exception as ex:
      logger.error("Exception during processing `receive_impacted_accounts` method: {0}".format(ex))
      raise ex

    return _items

  def execute_complex_query(self, queries, low, high, q_parts):
    if len(queries) == 0:
      return

    cnt = 0
    _total_query = q_parts[0]

    for i in range(low, high + 1):
      _total_query += ( "," if cnt else "" ) + queries[i]
      cnt += 1

    _total_query += q_parts[2]

    self.perform_query(_total_query)

  def send_accounts(self, clone_sql_executor, accounts_queries):
    try:
      if len(accounts_queries) == 0:
        logger.info("Lack of accounts...")
        return

      logger.info("INSERT INTO to `accounts`: {} records".format(len(accounts_queries)))

      clone_sql_executor.execute_complex_query(accounts_queries, 0, len(accounts_queries) - 1, sql_data.query.insert_into_accounts)
    except Exception as ex:
      logger.error("Exception during processing `send_accounts` method: {0}".format(ex))
      raise ex

  def send_account_operations(self, clone_sql_executor, account_ops_queries, first_element, last_element):
    try:
      logger.info("INSERT INTO to `account_operations`: first element: {} last element: {}".format(first_element, last_element))

      clone_sql_executor.execute_complex_query(account_ops_queries, first_element, last_element, sql_data.query.insert_into_account_ops)
    except Exception as ex:
      logger.error("Exception during processing `send_account_operations` method: {0}".format(ex))
      raise ex

class sql_executor_pool:
  def __init__(self):
    self.idx           = 0
    self.sql_executors = []

  def create_executors(self, src_sql_executor, size):
    self.sql_executors.clear()

    assert size > 0, "size > 0"

    for i in range(size):
      self.sql_executors.append(src_sql_executor.clone())


  def get_item(self):
    assert len(self.sql_executors) > 0, "len(self.sql_executors) > 0"

    _current_idx  = self.idx
    self.idx           += 1
    if self.idx == len(self.sql_executors):
      self.idx = 0

    assert self.idx < len(self.sql_executors), "self.idx < len(self.sql_executors)"

    return self.sql_executors[_current_idx]

class ah_loader(metaclass = singleton):

  def __init__(self):
    self.is_massive           = True
    self.interrupted          = False

    self.last_block_num       = 0

    self.application_context  = "account_history_python"

    self.accounts_queries     = []
    self.account_ops_queries  = []

    self.account_cache        = {}

    self.block_ranges         = deque()

    self.finished             = False
    self.queue                = None

    self.sql_executor         = sql_executor()

    self.sql_pool             = sql_executor_pool()

  def read_file(self, path):
    with open(path, 'r') as file:
      return file.read()
    return ""

  def import_accounts(self):
    if self.is_interrupted():
      return

    _accounts = self.sql_executor.perform_query_all(sql_data.query.accounts)

    if _accounts is None:
      return

    for _record in _accounts:
      _id   = int(_record["id"])
      _name = str(_record["name"])

      if _id > account_info.next_account_id:
        account_info.next_account_id = _id

      self.account_cache[_name] = account_info(_id, 0)

    if account_info.next_account_id:
      account_info.next_account_id += 1

  def import_account_operations(self):
    if self.is_interrupted():
      return

    _account_ops = self.sql_executor.perform_query_all(sql_data.query.account_ops)

    if _account_ops is None:
      return

    for _record in _account_ops:
      _name             = str(_record["name"])
      _operation_count  = int(_record["operation_count"])

      found = _name in self.account_cache
      assert found, "found"
      self.account_cache[_name].operation_count = _operation_count

  def import_initial_data(self):
    self.import_accounts()
    self.import_account_operations()

  def context_exists(self):
    return self.sql_executor.perform_query_one(sql_data.query.check_context)

  def context_is_attached(self):
    return self.sql_executor.perform_query_one(sql_data.query.context_is_attached)

  def context_detached_get_block_num(self):
    _result = self.sql_executor.perform_query_one(sql_data.query.context_detached_get_block_num)
    if _result is None:
      _result = 0
    return _result

  def switch_context_internal(self, force_attach, last_block = 0):
    _is_attached = self.context_is_attached()

    if _is_attached == force_attach:
      return

    if force_attach:
      if last_block == 0:
        last_block = self.context_detached_get_block_num()

      _attach_context_query = sql_data.query.attach_context.format(self.application_context, last_block)
      self.sql_executor.perform_query(_attach_context_query)
    else:
      self.sql_executor.perform_query(sql_data.query.detach_context)

  def attach_context(self, last_block = 0):
    #True value of force_attach
    logger.info("Attaching context... Last block:".format(last_block))
    self.switch_context_internal(True, last_block)

  def detach_context(self):
    #False value of force_attach
    logger.info("Detaching context...")
    self.switch_context_internal(False)

  def gather_part_of_queries(self, operation_id, account_name):
    found = account_name in self.account_cache

    _next_account_id = account_info.next_account_id
    _op_cnt = 0

    if not found:
      self.account_cache[account_name] = account_info(_next_account_id, _op_cnt)
      self.accounts_queries.append(sql_data.query.insert_into_accounts[1].format(_next_account_id, account_name))

      account_info.next_account_id += 1
    else:
      _next_account_id  = self.account_cache[account_name].id
      self.account_cache[account_name].operation_count += 1
      _op_cnt           = self.account_cache[account_name].operation_count

    self.account_ops_queries.append(sql_data.query.insert_into_account_ops[1].format(_next_account_id, _op_cnt, operation_id))

  def init(self, args):
    sql_data.query  = ah_query(self.application_context)
    sql_data.args   = args

    self.sql_executor.init()

    self.queue  = queue.Queue(maxsize = 200)

    self.sql_pool.create_executors(self.sql_executor, sql_data.args.threads_receive + sql_data.args.threads_send + 1)

  def interrupt(self):
    if not self.is_interrupted():
      self.interrupted = True

  def is_interrupted(self):
    return self.interrupted

  def raise_exception(self, source_exception):
    self.interrupt()
    raise source_exception

  def prepare(self):
    if self.is_interrupted():
      return

    try:
      if not self.context_exists():
        tables_query    = self.read_file( sql_data.args.schema_path + "/ah_schema_tables.sql" )
        functions_query = self.read_file( sql_data.args.schema_path + "/ah_schema_functions.sql" )

        self.sql_executor.perform_query(sql_data.query.create_context)

        self.sql_executor.perform_query(tables_query)
        self.sql_executor.perform_query(functions_query)

      self.import_initial_data()

    except Exception as ex:
      print(ex)
      logger.error("Exception during processing `prepare` method: {0}".format(ex))
      self.raise_exception(ex)

  def prepare_ranges(self, low_value, high_value, threads):
    assert threads > 0 and threads <= 64, "threads > 0 and threads <= 64"

    if threads == 1 or not self.is_massive:
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

  def receive_data(self, first_block, last_block):
    try:
      _ranges = self.prepare_ranges(first_block, last_block, sql_data.args.threads_receive)
      assert len(_ranges) > 0

      _futures = []

      with ThreadPoolExecutor(max_workers=len(_ranges)) as executor:
        for range in _ranges:
          if self.is_interrupted():
            break
          _futures.append(executor.submit(self.sql_executor.receive_impacted_accounts, self.sql_pool.get_item(), range.low, range.high))

      _elements = []
      for future in _futures:
        _elements.append(future.result())

      if len(_elements) == 0:
        return

      _result = {'block' : last_block, 'elements' : _elements}

      _inserted  = False
      _put_delay = 1#[s]
      _sleep     = 1#[s]

      while not _inserted:
        try:
          self.queue.put(_result, True, _put_delay)
          _inserted = True
        except queue.Full:
          logger.info("Queue is full... Waiting {} seconds".format(_sleep))
          time.sleep(_sleep)
    except Exception as ex:
      logger.error("Exception during processing `receive_data` method: {0}".format(ex))
      self.raise_exception(ex)

  def receive(self):
    while len(self.block_ranges) > 0:
      if self.is_interrupted():
        break

      start = datetime.datetime.now()

      _item = self.block_ranges.popleft()

      self.receive_data( _item.low, _item.high )

      end = datetime.datetime.now()
      logger.info("receive time[ms]: {}".format(helper.get_time(start, end)))

    self.finished = True

  def prepare_sql(self):
    _received  = False
    _get_delay = 1#[s]
    _sleep     = 1#[s]

    cnt   = 0
    tries = 1

    received_items_block = None
    while not _received:
      try:
        try:
          received_items_block = self.queue.get(True, _get_delay)
          _received = True
        except queue.Empty:
          if self.finished:
            if cnt < tries:
              logger.info("Queue is probably empty... Try: {}/{}".format(cnt/tries))
              cnt += 1
            else:
              logger.info("Queue is empty... All data was received")
              break
          else:
            logger.info("Queue is empty... Waiting {} seconds".format(_sleep))
            time.sleep(_sleep)
            if self.is_interrupted():
              break
      except Exception as ex:
        logger.error("Exception during processing `prepare_sql` method: {0}".format(ex))
        self.raise_exception(ex)

    if received_items_block is None:
      logger.info("Lack of impacted accounts...")
      return None

    if 'elements' not in received_items_block:
      logger.info("Lack of impacted accounts - empty set...")
      return None

    for items in received_items_block['elements']:
      for item in items:
        self.gather_part_of_queries( item.op_id, item.name )

    return received_items_block['block']

  def send_data(self):
    try:

      _futures = []

      with ThreadPoolExecutor(max_workers = 1) as executor:
        _futures.append(executor.submit(self.sql_executor.send_accounts, self.sql_pool.get_item(), self.accounts_queries))

      if len(self.account_ops_queries) == 0:
        logger.info("Lack of operations...")
      else:
        _ranges = self.prepare_ranges(0, len(self.account_ops_queries) - 1, sql_data.args.threads_send)
        assert len(_ranges) > 0

      with ThreadPoolExecutor(max_workers = len(_ranges)) as executor:
        for range in _ranges:
          _futures.append(executor.submit(self.sql_executor.send_account_operations, self.sql_pool.get_item(), self.account_ops_queries, range.low, range.high))

      for future in as_completed(_futures):
        future.result()

      self.accounts_queries.clear()
      self.account_ops_queries.clear()
    except Exception as ex:
      logger.error("Exception during processing `send_data` method: {0}".format(ex))
      self.raise_exception(ex)

  def save_detached_block_num(self, block_num):
    try:
      logger.info("Saving detached block number: {}".format(block_num))

      _query = sql_data.query.context_detached_save_block_num.format(sql_data.query.application_context, block_num)
      self.sql_executor.perform_query(_query)
    except Exception as ex:
      logger.error("Exception during processing `save_detached_block_num` method: {0}".format(ex))
      self.raise_exception(ex)

  def send(self):
    logger.info("Sending...")
    while True:
      start = datetime.datetime.now()

      self.last_block_num = self.prepare_sql()

      self.send_data()

      if self.is_massive and self.last_block_num is not None:
        self.save_detached_block_num(self.last_block_num)

      end = datetime.datetime.now()
      logger.info("send time[ms]: {}".format(helper.get_time(start, end)))

      if self.finished and self.queue.empty():
        logger.info("Sending is finished...")
        break
      if self.is_interrupted():
        logger.info("Sending is interrupted...")
        break

  def work(self):
    if self.is_interrupted():
      return

    _futures = []
    with ThreadPoolExecutor(max_workers = 2) as executor:
      _futures.append(executor.submit(self.receive))
      _futures.append(executor.submit(self.send))

    for future in as_completed(_futures):
      future.result()

  def fill_block_ranges(self, first_block, last_block):
    if first_block == last_block:
      self.block_ranges.append(range_type(first_block, last_block))
      return

    _last_block = first_block

    while _last_block != last_block:
      _last_block = min(_last_block + sql_data.args.flush_size, last_block)
      self.block_ranges.append(range_type(first_block, _last_block))
      first_block = _last_block + 1

  def process(self):
    if self.is_interrupted():
      return True

    try:
      _first_block = 0
      _last_block  = 0

      self.attach_context()
      _range_blocks = self.sql_executor.perform_query_all(sql_data.query.next_block)

      if _range_blocks is not None and len(_range_blocks) > 0:
        assert len(_range_blocks) == 1

        record = _range_blocks[0]

        if record[0] is None or record[1] is None:
          logger.info("Values in range blocks have NULL")
          return True
        else:
          _first_block  = int(record[0])
          _last_block   = int(record[1])

        logger.info("first block: {} last block: {}".format(_first_block, _last_block))

        self.fill_block_ranges(_first_block, _last_block)

        self.is_massive = _last_block - _first_block > 0

        if self.is_massive:
          self.detach_context()

          self.work()

          self.attach_context(self.last_block_num if (self.last_block_num is not None) else 0)
        else:
          self.work()

        return False
      else:
        logger.info("Range blocks is returned empty")
        return True
    except Exception as ex:
      logger.error("Exception during processing `process` method: {0}".format(ex))
      self.raise_exception(ex)

def allow_close_app(empty, declared_empty_results, cnt_empty_result):
  _res = False

  cnt_empty_result = ( cnt_empty_result + 1 ) if empty else 0

  if declared_empty_results == -1:
    if empty:
      logger.info("A result returned from a database is empty. Actual empty result: {}".format(cnt_empty_result))
  else:
    if empty:
      logger.info("A result returned from a database is empty. Declared empty results: {} Actual empty result: {}".format(declared_empty_results, cnt_empty_result))

      if declared_empty_results < cnt_empty_result:
        _res = True

  return _res, cnt_empty_result

def shutdown_properly(signal, frame):
  logger.info("Closing. Wait...")

  _loader = ah_loader()
  _loader.interrupt()

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

# ./program --url postgresql://postgres:pass@127.0.0.1:5432/hafah --schema-dir /home/kmochocki/hf/HAfAH/ah/synchronization/queries --range-blocks-flush 40000 --allowed-empty-results 2 --threads-receive 6 --threads-send 6

  parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
  parser.add_argument("--schema-dir", type = str, help = "directory where schemas are stored")
  parser.add_argument("--range-blocks-flush", type = int, default = 1000, help = "Number of blocks processed at once")
  parser.add_argument("--allowed-empty-results", type = int, default = -1, help = "Allowed number of empty results from a database. After N tries, an application closes. A value `-1` means an infinite number of tries")
  parser.add_argument("--threads-receive", type = int, default = 1, help = "Number of threads that are used during retrieving `get_impacted_accounts` data")
  parser.add_argument("--threads-send", type = int, default = 1, help = "Number of threads that are used during sending data into database")

  _args = parser.parse_args()

  return _args.url, _args.schema_dir, _args.range_blocks_flush, _args.allowed_empty_results, _args.threads_receive, _args.threads_send

def main():
  try:

    logger.info("Synchronization with account history database...")

    _url, _schema_dir, _range_blocks_flush, _allowed_empty_results, _threads_receive, _threads_send = process_arguments()

    _loader = ah_loader()

    _loader.init( args_container(_url, _schema_dir, _range_blocks_flush, _threads_receive, _threads_send) )

    set_handlers()

    _loader.prepare()

    cnt_empty_result = 0
    declared_empty_results = _allowed_empty_results

    total_start = datetime.datetime.now()

    while not _loader.is_interrupted():
      start = datetime.datetime.now()

      empty = _loader.process()

      end = datetime.datetime.now()
      logger.info("time[ms]: {}\n".format(helper.get_time(start, end)))
 
      _allow_close, cnt_empty_result = allow_close_app( empty, declared_empty_results, cnt_empty_result )
      if _allow_close:
        break

    total_end = datetime.datetime.now()
    logger.info("*****Total time*****")
    logger.info("total time[s]: {}".format((total_end - total_start).seconds))

    if _loader.is_interrupted():
      logger.info("An application was interrupted...")

    restore_handlers()

  except Exception as ex:
    logger.error("Exception during processing `main` method: {0}".format(ex))
    exit(1)

  return exit(0)

if __name__ == '__main__':
  main()

