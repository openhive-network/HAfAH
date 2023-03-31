from typing import Any, Dict, Tuple
from uuid import uuid4

import pytest
import sqlalchemy
from sqlalchemy_utils import database_exists, create_database, drop_database
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import sessionmaker, close_all_sessions
from sqlalchemy.pool import NullPool

from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import
import test_tools as tt

from haf_local_tools.witnesses import alpha_witness_names, beta_witness_names, alpha_witness_names_17, beta_witness_names_3


def pytest_exception_interact(report):
    tt.logger.error(f'Test exception:\n{report.longreprtext}')


@pytest.fixture()
def witness_names():
    return alpha_witness_names, beta_witness_names

@pytest.fixture()
def witness_names_17_3():
    return alpha_witness_names_17, beta_witness_names_3

@pytest.fixture()
def database():
    """
    Returns factory function that creates database with parametrized name and extension hive_fork_manager installed
    """

    def make_database(url):
        url = url + '_' + uuid4().hex
        tt.logger.info(f'Preparing database {url}')
        if database_exists(url):
            drop_database(url)
        create_database(url)

        engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
        with engine.connect() as connection:
            connection.execute('CREATE EXTENSION hive_fork_manager CASCADE;')

        with engine.connect() as connection:
            connection.execute('SET ROLE hived_group')

        Session = sessionmaker(bind=engine)
        session = Session()

        return session

    yield make_database

    close_all_sessions()


def prepared_networks_and_database_internal(database, current_witness_names) -> Tuple[Dict[str, tt.Network], Any]:
    alpha_witness_names, beta_witness_names = current_witness_names
    session = database('postgresql:///haf_block_log')

    alpha_net = tt.Network()
    tt.InitNode(network=alpha_net)
    tt.WitnessNode(network=alpha_net, witnesses=alpha_witness_names)

    beta_net = tt.Network()
    tt.WitnessNode(network=beta_net, witnesses=beta_witness_names)
    node_under_test = tt.ApiNode(network=beta_net)
    node_under_test.config.plugin.append('sql_serializer')
    node_under_test.config.psql_url = str(session.get_bind().url)

    for node in [*alpha_net.nodes, *beta_net.nodes]:
        node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                                 '{"name":"sync","level":"debug","appender":"p2p"} '\
                                 '{"name":"p2p","level":"debug","appender":"p2p"}'

    networks = {
        'Alpha': alpha_net,
        'Beta': beta_net,
    }

    return networks, session

@pytest.fixture()
def prepared_networks_and_database(database, witness_names) -> Tuple[Dict[str, tt.Network], Any]:
    yield prepared_networks_and_database_internal(database, witness_names)


@pytest.fixture()
def prepared_networks_and_database_17_3(database, witness_names_17_3) -> Tuple[Dict[str, tt.Network], Any]:
    yield prepared_networks_and_database_internal(database, witness_names_17_3)
