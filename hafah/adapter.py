# -*- coding: utf-8 -*-
"""Wrapper for sqlalchemy, providing a simple interface."""

import simplejson
import sqlalchemy

from hafah.logger import get_logger

log = get_logger(module_name=__name__)

class Db:
    """RDBMS adapter for hive. Handles connecting and querying."""

    _instance = None

    #maximum number of connections that is required so as to execute some tasks concurrently
    necessary_connections = 15
    max_connections = 1

    @classmethod
    def instance(cls):
        """Get the shared instance."""
        assert cls._instance, 'set_shared_instance was never called'
        return cls._instance

    @classmethod
    def set_shared_instance(cls, db):
        """Set the global/shared db instance. Do not use."""
        cls._instance = db

    def __init__(self, url, name):
        """Initialize an instance.

        No work is performed here. Some modues might initialize an
        instance before config is loaded.
        """
        assert url, ('--database-url (or DATABASE_URL env) not specified; '
                     'e.g. postgresql://user:pass@localhost:5432/hive')
        self._url = url
        self._conn = []
        self._engine = None
        self._trx_active = False
        self._prep_sql = {}

        self.name = name

        self._conn.append( { "connection" : self.engine().connect(), "name" : name } )
        # Since we need to manage transactions ourselves, yet the
        # core behavior of DBAPI (per PEP-0249) is that a transaction
        # is always in progress, this COMMIT is a workaround to get
        # back control (and used with autocommit=False query exec).
        self._basic_connection = self.get_connection(0)
        self._basic_connection.execute(sqlalchemy.text("COMMIT"))

    def clone(self, name):
        cloned = Db(self._url, name)
        cloned._engine = self._engine

        return cloned

    def close(self):
        """Close connection."""
        try:
            for item in self._conn:
                if item is not None:
                    log.info("Closing database connection: '{}'".format(item['name']))
                    item['connection'].close()
                    item = None
            self._conn = []
        except Exception as ex:
            log.exception("Error during connections closing: {}".format(ex))
            raise ex

    def close_engine(self):
        """Dispose db instance."""
        try:
            if self._engine is not None:
                log.info("Disposing SQL engine")
                self._engine.dispose()
                self._engine = None
            else:
              log.info("SQL engine was already disposed")
        except Exception as ex:
            log.exception("Error during database closing: {}".format(ex))
            raise ex

    def get_connection(self, number):
        assert len(self._conn) > number, "Incorrect number of connection. total: {} number: {}".format(len(self._conn), number)
        assert 'connection' in self._conn[number], 'Incorrect construction of db connection'
        return self._conn[number]['connection']

    def engine(self):
        """Lazy-loaded SQLAlchemy engine."""
        if self._engine is None:
            self._engine = sqlalchemy.create_engine(
                self._url,
                isolation_level="READ UNCOMMITTED", # only supported in mysql
                pool_size=self.max_connections,
                pool_recycle=3600,
                echo=False,
                json_deserializer=simplejson.loads
            )
        return self._engine

    def get_new_connection(self, name):
        self._conn.append( { "connection" : self.engine().connect(), "name" : name } )
        return self.get_connection(len(self._conn) - 1)

    def get_dialect(self):
        return self.get_connection(0).dialect

    def is_trx_active(self):
        """Check if a transaction is in progress."""
        return self._trx_active

    def query_no_return(self, sql, **kwargs):
        self._query(sql, False, **kwargs)

    def query_all(self, sql, **kwargs):
        """Perform a `SELECT n*m`"""
        query, res = self._query(sql, False, **kwargs)
        return query, res.fetchall()

    def _sql_text(self, sql, is_prepared, **kwargs):
        if is_prepared:
            return sql
        else:
            return str(sqlalchemy.text(sql).bindparams(**kwargs).execution_options(autocommit=False).compile(dialect=self.get_dialect(), compile_kwargs={"literal_binds": True}))

    def _query(self, sql, is_prepared, **kwargs):
        """Send a query off to SQLAlchemy."""
        if sql == 'START TRANSACTION':
            assert not self._trx_active
            self._trx_active = True
        elif sql == 'COMMIT':
            assert self._trx_active
            self._trx_active = False

        try:
            query : str = self._sql_text(sql, is_prepared, **kwargs)
            return query, self._basic_connection.execute(query)
        except Exception as e:
            log.warning(f"[SQL-ERR] `{type(e).__name__}` in query `{query}`")
            raise e
