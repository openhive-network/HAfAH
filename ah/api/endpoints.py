from ah.db.backend import account_history_impl

class backend_singleton:
  __m_backend = None
  def __init__(self, db_url):
    backend_singleton.__m_backend = account_history_impl(db_url)

  @staticmethod
  def backend():
    assert backend_singleton.__m_backend is not None
    return backend_singleton.__m_backend

def backend():
  return backend_singleton.backend()

def build_response( obj ):
  from json import dumps
  return obj

async def get_ops_in_block(block_num : int, only_virtual : bool, include_reversible : bool = True):
  return build_response( await backend().get_ops_in_block( block_num, only_virtual, include_reversible) )

async def enum_virtual_ops(block_range_begin : int, block_range_end : int, operation_begin : int = 0, limit : int = 1_000, filter : int = 0, include_reversible : bool = True ):
  return build_response( await backend().enum_virtual_ops( filter, block_range_begin, block_range_end, operation_begin, limit, include_reversible) )

async def get_transaction(trx_hash : str ):
  return build_response( await backend().get_transaction( trx_hash ) )

async def get_account_history(account : str, start : int, limit : int, operation_filter_low : int = 0, operation_filter_high : int = 0, include_reversible : bool = True):
  filter = ( operation_filter_low << 0xFFFFFFFF ) | operation_filter_high
  assert isinstance(filter, int)
  return build_response( await backend().get_account_history( filter, account, start, limit, include_reversible ) )

def build_methods():
  def method( foo ):
    return (f'account_history_api.{foo.__name__}', foo)

  methods = dict([
    method( get_ops_in_block ),
    method( enum_virtual_ops ),
    method( get_transaction ),
    method( get_account_history )
  ])
  return methods