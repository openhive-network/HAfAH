##   To run job locally in docker, use below two commands:

docker run -d \
  --name gitlab-runner \
  --restart always \
  --network host \
  -v `git rev-parse --show-toplevel`:$PWD \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

docker exec -it -w $PWD gitlab-runner \
  gitlab-runner exec docker patterns_tests \
  --env 'CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah' \
  --env 'POSTGRESQL_URI=postgresql://myuser:mypassword@localhost/hafah'

##   when executing job use one of environment variables: POSTGRESQL_URI or AH_ENDPOINT
###  POSTGRESQL_URI is address of haf database with 5 milion blocks, is POSTGRESQL_URI is provided
###  and AH_ENDPOINT is not, then local hafah instance will run it will use provided database
###  AH_ENDPOINT is address (protocol://ip:port) of account history endpoint to perform tests

###  alternatively use command tox when in this directory, provided that AH_ENDPOINT environment variable
###  is set and pointing to hafah instance
