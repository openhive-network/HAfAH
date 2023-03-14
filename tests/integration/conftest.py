import json
import os
import socket
import shutil
import subprocess
import time
from os.path import dirname, realpath
from pathlib import Path
from typing import Any, Dict, Tuple, Callable
from uuid import uuid4

import pytest
import sqlalchemy
from sqlalchemy.orm import close_all_sessions, sessionmaker, Session
from sqlalchemy.pool import NullPool
from sqlalchemy_utils import create_database, database_exists, drop_database

import test_tools as tt
from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import


def get_ah_schema_functions_pgsql_content():
    with (Path(dirname(realpath(__file__))) / '..' / '..' / 'queries' / 'ah_schema_functions.pgsql').open('rt') as pgsql:
        content_pgsql = pgsql.read()
        return content_pgsql


def get_hafah_backend_sql_content():
    with (Path(dirname(realpath(__file__))) / '..' / '..' / 'postgrest' / 'hafah_backend.sql').open('rt') as sql:
        content_sql = sql.read()
        return content_sql


def get_hafah_endpoints_sql_content():
    with (Path(dirname(realpath(__file__))) / '..' / '..' / 'postgrest' / 'hafah_endpoints.sql').open('rt') as sql:
        content_sql = sql.read()
        return content_sql


def pytest_exception_interact(report):
    tt.logger.error(f'Test exception:\n{report.longreprtext}')


@pytest.fixture()
def database() -> Callable[[], Session]:
    """
    Returns factory function that creates database with parametrized name and extension hive_fork_manager installed
    """

    def make_database(url) -> Session:
        url = url + '_' + uuid4().hex
        tt.logger.info(f'Preparing database {url}')
        if database_exists(url):
            drop_database(url)
        create_database(url)

        engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)

        with engine.connect() as connection:
            db_name = url.split("/")[-1]
            connection.execute('CREATE EXTENSION hive_fork_manager CASCADE;')
            connection.execute(f'GRANT ALL PRIVILEGES ON DATABASE {db_name} TO hafah_owner;')
            connection.execute(statement=sqlalchemy.text(get_ah_schema_functions_pgsql_content()))
            connection.execute(statement=sqlalchemy.text(get_hafah_backend_sql_content()))
            connection.execute(statement=sqlalchemy.text(get_hafah_endpoints_sql_content()))
            connection.execute("COMMIT;")
            connection.execute('SET ROLE hafah_owner')

        Session = sessionmaker(bind=engine)
        session = Session()

        return session

    yield make_database

    close_all_sessions()


@pytest.fixture()
def db_session(database) -> Session:
    return database('postgresql:///haf_block_log')


@pytest.fixture()
def node_with_sql_serializer(db_session) -> tt.InitNode:
    node = tt.InitNode()
    node.config.plugin.append('sql_serializer')
    node.config.psql_url = str(db_session.get_bind().url)
    node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                             '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                             '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                             '{"name":"sync","level":"debug","appender":"p2p"} '\
                             '{"name":"p2p","level":"debug","appender":"p2p"}'
    node.run(wait_for_live=True)
    yield node


@pytest.fixture()
def postgrest(db_session, node_with_sql_serializer) -> tt.RemoteNode:
    sock = socket.socket()
    sock.bind(('', 3001))
    port = sock.getsockname()[1]

    # Set environment variables needed to postgrest
    environment = os.environ
    environment['PGRST_DB_URI'] = str(db_session.get_bind().url)
    environment['PGRST_DB_SCHEMA'] = "hafah_endpoints"
    environment['PGRST_DB_ANON_ROLE'] = "hafah_user"
    environment['PGRST_DB_ROOT_SPEC'] = "home"
    environment['PGRST_SERVER_PORT'] = f"{port}"

    postgrest_workdir = node_with_sql_serializer.directory.parent / "postgrest"
    if postgrest_workdir.exists():
        shutil.rmtree(postgrest_workdir)
    postgrest_workdir.mkdir()

    with (postgrest_workdir / "environments.json").open("wt") as envs_out:
        json.dump(dict(environment), envs_out, indent=2, sort_keys=True, ensure_ascii=False)

    sock.close()
    with (postgrest_workdir / "stderr.postgrest.log").open("wt") as stderr, \
            (postgrest_workdir / "stdout.postgrest.log").open("wt") as stdout, \
            subprocess.Popen(["/usr/local/bin/postgrest"], env=environment, stderr=stderr, stdout=stdout) as proc:

        time.sleep(1)
        yield tt.RemoteNode(f"localhost:{port}")

        proc.kill()
        proc.wait(3)
