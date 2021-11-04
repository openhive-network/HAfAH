from pytest import fixture


def pytest_addoption(parser):
    parser.addoption( "--ref", action="store", type=str, help='specifies address of reference node')
    parser.addoption( "--test", action="store", type=str, help='specifies address of tested service')
    parser.addoption( "--hashes", action="store", type=str, help='specifies path to file with hashes to check (one per line)')