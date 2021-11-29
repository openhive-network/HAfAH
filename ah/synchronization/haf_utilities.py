from time import perf_counter

class range_type:
  def __init__(self, low, high):
    self.low  = low
    self.high = high

class args_container:
  def __init__(self, url = "", range_blocks = 1000):
    self.url          = url
    self.range_blocks = range_blocks

class helper:
  args    = None
  logger  = None

  @staticmethod
  def log(info, *args):
    if helper.logger is not None:
      helper.logger.info(info.format(*args))

  @staticmethod
  def display_query(query):
    if len(query) > 100:
      helper.log("{}...", query[0:100])
    else:
      helper.log("{}", query)

  @staticmethod
  def execute_complex_query(app, values, q_parts):
    if len(values) == 0:
      return

    cnt = 0
    _total_query = q_parts[0]

    for item in values:
      _total_query += ( "," if cnt else "" ) + item
      cnt += 1

    _total_query += q_parts[2]

    _result = app.exec_query(_total_query)

class timer:
  def __init__(self, message):
    self.message  = message
    self.start    = None

  def __enter__(self):
    self.start    = perf_counter()
    return self

  def __exit__(self, *args, **kwargs):
    self.time = int((perf_counter() - self.start)*1000)
    helper.log(self.message.format(self.time))
