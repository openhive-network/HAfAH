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

#the simplest handler of callbacks
class callback_handler:
  def __init__(self, logger = None, pre_none_ctx = None, pre_is_ctx = None, pre_always = None, run = None, post = None):

    self.logger = logger

    #preprocessing: a context doesn't exist
    self.pre_none_ctx = pre_none_ctx

    #preprocessing: a context exists
    self.pre_is_ctx   = pre_is_ctx

    #preprocessing: it doesn't matter if a context exists or doesn't
    self.pre_always   = pre_always

    #processing all blocks retrieved from db
    self.run  = run

    #postprocessing
    self.post = post

class timer:
  def __init__(self, message):
    self.message  = message
    self.start    = None

  def __enter__(self):
    self.start    = perf_counter()
    return self

  def __exit__(self, *args, **kwargs):
    self.time = int((perf_counter() - self.start)*1000)
    assert helper.logger is not None, "`helper.logger` should be initialized"
    helper.logger.info(self.message.format(self.time))
