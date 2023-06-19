from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import


def pytest_addoption(parser):
    parser.addoption(
        "--postgrest-hafah-path", action="store", type=str, help="specifies path of hafah postgrest"
    )


@pytest.fixture
def postgrest_hafah_path(request):
    return request.config.getoption("--postgrest-hafah-path")
