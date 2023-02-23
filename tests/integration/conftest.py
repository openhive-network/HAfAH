import json
import os
import socket
import shutil
import subprocess
import time

import pytest

import test_tools as tt
from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import connect_nodes


def pytest_addoption(parser):
    parser.addoption(
        "--postgrest-hafah-path", action="store", type=str, help="specifies path of hafah postgrest"
    )


@pytest.fixture
def postgrest_hafah_path(request):
    return request.config.getoption("--postgrest-hafah-path")


@pytest.fixture()
def node_set():
    init_node = tt.InitNode()
    init_node.run()
    DB_URL = os.getenv("DB_URL")
    haf_node = HafNode(database_url=DB_URL)
    connect_nodes(init_node, haf_node)
    haf_node.run()
    return init_node, haf_node


@pytest.fixture()
def postgrest_hafah(node_set, postgrest_hafah_path) -> tt.RemoteNode:
    init_node, haf_node = node_set
    sock = socket.socket()
    sock.bind(('', 0))
    port = sock.getsockname()[1]

    # Set environment variables needed to postgrest
    environment = os.environ
    environment['PGRST_DB_URI'] = str(haf_node.database_url)
    environment['PGRST_DB_SCHEMA'] = "hafah_endpoints"
    environment['PGRST_DB_ANON_ROLE'] = "hafah_user"
    environment['PGRST_DB_ROOT_SPEC'] = "home"
    environment['PGRST_SERVER_PORT'] = f"{port}"

    postgrest_workdir = haf_node.directory.parent / "postgrest"
    if postgrest_workdir.exists():
        shutil.rmtree(postgrest_workdir)
    postgrest_workdir.mkdir()

    with (postgrest_workdir / "environments.json").open("wt") as envs_out:
        json.dump(dict(environment), envs_out, indent=2, sort_keys=True, ensure_ascii=False)

    sock.close()
    with (postgrest_workdir / "stderr.postgrest.log").open("wt") as stderr, \
            (postgrest_workdir / "stdout.postgrest.log").open("wt") as stdout, \
            subprocess.Popen([postgrest_hafah_path], env=environment, stderr=stderr, stdout=stdout) as proc:

        time.sleep(5)
        yield tt.RemoteNode(f"localhost:{port}")

        proc.kill()
        proc.wait(3)
