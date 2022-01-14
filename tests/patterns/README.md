###   To run job locally in docker, use below two commands:

docker run -d \
  --name gitlab-runner \
  --restart always \
  --network host \
  -v `git rev-parse --show-toplevel`:`git rev-parse --show-toplevel` \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

docker exec -it -w `git rev-parse --show-toplevel` gitlab-runner \
  gitlab-runner exec docker patterns_tests \
  --docker-network-mode host \
  --env 'CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah' \
  --env 'POSTGRESQL_URI=postgresql://myuser:mypassword@localhost/hafah'


###  when executing job locally use one of environment variables: POSTGRESQL_URI or AH_ENDPOINT
###  POSTGRESQL_URI should be address of haf database with 5 milion blocks
###  AH_ENDPOINT is address (protocol://ip:port) of account history endpoint to perform tests

###  alternatively use command tox when in this directory, provided that AH_ENDPOINT environment variable
###  is set and pointing to hafah instance
