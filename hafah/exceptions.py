# -*- coding: utf-8 -*-
from jsonrpcserver.exceptions import ApiError

JSON_RPC_SERVER_ERROR       = -32000
JSON_RPC_ERROR_DURING_CALL  = -32003

class SQLExceptionWrapper(ApiError):
  def __init__(self, msg):
    super().__init__(msg, JSON_RPC_ERROR_DURING_CALL)

class InternalServerException(ApiError):
  def __init__(self, msg):
    super().__init__(msg, JSON_RPC_ERROR_DURING_CALL)

class CustomUInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse uint64_t", JSON_RPC_SERVER_ERROR)

class CustomInt64ParserApiException(ApiError):
  def __init__(self):
    super().__init__("Parse Error:Couldn't parse int64_t", JSON_RPC_SERVER_ERROR)

class CustomBoolParserApiException(ApiError):
  def __init__(self):
    super().__init__("Bad Cast:Cannot convert string to bool (only \"true\" or \"false\" can be converted)", JSON_RPC_SERVER_ERROR)

class CustomInvalidTransactionHashLength(ApiError):
  def __init__(self, hash):
    super().__init__(f"Assert Exception:false: Transaction hash '{hash}' has invalid size. Transaction hash should have size of 160 bits", JSON_RPC_ERROR_DURING_CALL)

class CustomInvalidCharInTransactionHash(ApiError):
  def __init__(self, char):
    super().__init__(f"unspecified:Invalid hex character '{char}'", JSON_RPC_SERVER_ERROR)