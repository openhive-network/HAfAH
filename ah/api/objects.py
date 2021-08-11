class result:
  def __init__( self, result, id : int, jsonrpc : str = "2.0" ):
    self.jsonrpc = jsonrpc
    self.result = result
    self.id = id
