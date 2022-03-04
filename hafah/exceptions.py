from jsonrpcserver.exceptions import ApiError

JSON_RPC_SERVER_ERROR       = -32000
JSON_RPC_ERROR_DURING_CALL  = -32003

class SQLExceptionWrapper(ApiError):
  def __init__(self, msg):
    super().__init__(msg, JSON_RPC_ERROR_DURING_CALL)

class CustomTransactionApiException(ApiError):
  def __init__(self, trx_hash):
    #because type of `trx_hash` is `ripemd160`
    trx_hash_size = 40

    if len(trx_hash) < trx_hash_size:
      for i in range(trx_hash_size - len(trx_hash)):
        trx_hash += '0'
    super().__init__("Assert Exception:false: Unknown Transaction {}".format(trx_hash), JSON_RPC_ERROR_DURING_CALL)

class CustomAccountHistoryApiException(ApiError):
  def __init__(self):
    super().__init__("Assert Exception:args.start >= args.limit-1: start must be greater than or equal to limit-1 (start is 0-based index)", JSON_RPC_ERROR_DURING_CALL)

class CustomUInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse uint64_t", JSON_RPC_SERVER_ERROR)

class CustomInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse int64_t", JSON_RPC_SERVER_ERROR)

class CustomBoolParserApiException(ApiError):
  def __init__(self):
    super().__init__("Bad Cast:Cannot convert string to bool (only \"true\" or \"false\" can be converted)", JSON_RPC_SERVER_ERROR)
