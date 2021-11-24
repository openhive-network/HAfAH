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
  def display_query(query):
    if len(query) > 100:
      helper.logger.info("{}...".format(query[0:100]))
    else:
      helper.logger.info("{}".format(query))

class callback_handler:
  def __init__(self, pre_none_ctx, pre_is_ctx, pre_always, run, post):
    #a context doesn't exist
    self.pre_none_ctx = pre_none_ctx

    #a context exists
    self.pre_is_ctx   = pre_is_ctx

    #it doesn't matter if a context exists or doesn't
    self.pre_always   = pre_always

    self.run  = run
    self.post = post

class timer:
  def __init__(self, message):
    self.message  = message
    self.start    = None

  def __enter__(self):
    self.start    = perf_counter()
    return self

  def __exit__(self, *args, **kwargs):
    self.time = perf_counter() - self.start
    assert helper.logger is not None, "`helper.logger` should be initialized"
    helper.logger.info(self.message.format(self.time))
