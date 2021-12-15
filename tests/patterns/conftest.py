import pytest
from pathlib import Path


@pytest.fixture(scope="function")
def script_name(request):
    return Path(request.fspath).name


@pytest.fixture(scope="function")
def script_directory(request):
    return Path(request.fspath).parent
