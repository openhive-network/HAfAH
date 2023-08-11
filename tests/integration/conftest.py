import docker
import shutil
import time

import pytest

import test_tools as tt
from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import connect_nodes


def pytest_addoption(parser):
    parser.addoption(
        "--postgrest-image",
        action="store",
        type=str,
        help="specifies image hafah postgrest",
    )
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
def postgrest_image(request):
    return request.config.getoption("--postgrest-image")


@pytest.fixture(scope="module")
def postgrest_hafah_adress(request):
    return request.config.getoption("--postgrest-hafah-adress")


@pytest.fixture(scope="module")
def postgres_db_url(request):
    return request.config.getoption("--postgres-db-url")


@pytest.fixture(scope="module")
def node_set(postgres_db_url, postgrest_hafah_adress):
    init_node = tt.InitNode()
    init_node.run()
    haf_node = HafNode(database_url=postgres_db_url, keep_database=True, create_unique_database=False)

    connect_nodes(init_node, haf_node)
    haf_node.run()

    postgrest_hafah = tt.RemoteNode(postgrest_hafah_adress)

    return init_node, haf_node, postgrest_hafah


@pytest.fixture(scope="module")
def wallet(node_set):
    init_node, haf_node, postgrest_hafah = node_set
    wallet = tt.Wallet(attach_to=init_node)
    return wallet


# @pytest.fixture(scope="module")
# def postgrest_hafah(postgrest_image, node_set, postgres_db_url) -> tt.RemoteNode:
#     init_node, haf_node = node_set

#     db_url = haf_node.database_url
#     db_name = db_url.split("/")[-1]

#     container, client = run_postgrest_container(postgrest_image, db_name, postgres_db_url)

#     container.reload()
#     container_info = container.attrs
#     ip_address = container_info["NetworkSettings"]["IPAddress"]

#     postgrest_node = tt.RemoteNode(f"{ip_address}:6543")

#     yield postgrest_node

#     postgrest_workdir = haf_node.directory.parent / "postgrest"
#     if postgrest_workdir.exists():
#         shutil.rmtree(postgrest_workdir)
#     postgrest_workdir.mkdir()

#     logs = container.logs().decode("utf-8")
#     with open(f"{postgrest_workdir}/logs.txt", "w") as file:
#         file.write(logs)
#     file.close()

#     # CLEANUP CONTAINERS
#     container.stop()
#     container.remove()
#     client.close()


# def run_postgrest_container(postgrest_image:str, db_name: str, postgres_db_url):
#     client = docker.from_env()

#     #ODWOŁUJ SIĘ PRZEZ NAZWĘ
#     postgres_url = f"{postgres_db_url}_{db_name.split('_')[-1]}"
#     # postgres_url = f"postgresql://haf_admin:password@172.17.0.2:5432/{db_name}"
#     # postgres_url = f"postgresql:///{db_name}"
#     # image_name = (
#     #     "registry.gitlab.syncad.com/hive/hafah/instance:instance-postgrest-a80b6a36"
#     # )

#     container = client.containers.run(
#         image=postgrest_image,
#         environment={"POSTGRES_URL": postgres_url},
#         detach=True,
#     )

#     time.sleep(5)
#     return container, client
