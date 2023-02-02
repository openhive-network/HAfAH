import os

import pytest

import test_tools as tt
from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import


def pytest_exception_interact(report):
    tt.logger.error(f'Test exception:\n{report.longreprtext}')


@pytest.fixture()
def apis():
    if not os.environ.get('ENDPOINT'):
        raise Exception('ENDPOINT environment variable not set')
    hafah_endpoint = os.environ.get('ENDPOINT')
    tt.logger.info(f'using ENDPOINT environment variable {hafah_endpoint}')

    if not os.environ.get('HIVED_HTTP_ENDPOINT'):
        raise Exception('HIVED_HTTP_ENDPOINT environment variable not set')
    hived_http_endpoint = os.environ.get('HIVED_HTTP_ENDPOINT')
    tt.logger.info(f'using HIVED_HTTP_ENDPOINT environment variable {hived_http_endpoint}')

    if not os.environ.get('HIVED_WS_ENDPOINT'):
        raise Exception('HIVED_WS_ENDPOINT environment variable not set')
    hived_ws_endpoint = os.environ.get('HIVED_WS_ENDPOINT')
    tt.logger.info(f'using HIVED_WS_ENDPOINT environment variable {hived_ws_endpoint}')

    hafah = tt.RemoteNode(http_endpoint=hafah_endpoint)
    node = tt.RemoteNode(http_endpoint=hived_http_endpoint, ws_endpoint=hived_ws_endpoint)
    return hafah, node
