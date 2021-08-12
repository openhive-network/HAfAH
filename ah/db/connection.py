from ah.api.objects import result
from sqlalchemy import text, create_engine
from sqlalchemy.engine.base import Engine

class Db:
  def __init__(self, connection_str) -> None:
    self.__db_engine = create_engine(connection_str)
    self.open()

  def instance(self) -> Engine:
    assert self.__db_connection is not None
    return self.__db_connection

  def exec(self, query, **kwargs):
    return self.instance().execute(text(query), **kwargs)

  def open(self):
    self.__db_connection = self.__db_engine.connect()

  def close(self):
    self.__db_connection.close()