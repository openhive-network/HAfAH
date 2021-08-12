import ah.api.endpoints as api_t
from ah.db.objects import virtual_ops
import asyncio
import pytest
from pytest import fixture

# if it fails here, verify that you have `pytest-asyncio` packet
# command to install: `pip3 install pytest-asyncio --user`
pytestmark = pytest.mark.asyncio