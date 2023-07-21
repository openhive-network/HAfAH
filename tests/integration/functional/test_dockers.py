import docker


def test_docker():
    client = docker.from_env()
    docker_version = client.version()

    client.close()