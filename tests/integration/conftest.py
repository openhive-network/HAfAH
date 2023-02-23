import pytest

import test_tools as tt
from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import connect_nodes


def pytest_addoption(parser):
    parser.addoption(
        "--postgres-db-url",
        action="store",
        type=str,
        help="specifies postgres db url",
    )
    parser.addoption(
        "--postgrest-hafah-adress",
        action="store",
        type=str,
        help="specifies postgres hafah adress",
    )


@pytest.fixture(scope="module")
def postgrest_hafah_adress(request):
    return request.config.getoption("--postgrest-hafah-adress")


@pytest.fixture(scope="module")
def postgres_db_url(request):
    return request.config.getoption("--postgres-db-url")


@pytest.fixture(scope="module")
def init_node():
    init_node = tt.InitNode()
    init_node.run()

    return init_node


@pytest.fixture(scope="module")
def haf_node(init_node, postgres_db_url):
    haf_node = HafNode(database_url=postgres_db_url, keep_database=True, create_unique_database=False)

    connect_nodes(init_node, haf_node)
    haf_node.run()

    return haf_node


@pytest.fixture(scope="module")
def postgrest_hafah(haf_node, postgrest_hafah_adress):
    # hafah implicitly requires the haf_noda to be running for proper operation
    postgrest_hafah = tt.RemoteNode(postgrest_hafah_adress)

    return postgrest_hafah


@pytest.fixture(scope="module")
def wallet(init_node):
    wallet = tt.Wallet(attach_to=init_node)
    return wallet
