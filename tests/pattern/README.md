docker pull gitlab/gitlab-runner

gitlab-runner exec docker my-job-name
gitlab-runner exec docker test --docker-volumes "/home/elboletaire/.ssh/id_rsa:/root/.ssh/id_rsa:ro"

docker run -d \
  --name gitlab-runner \
  --restart no \
  -v $PWD:$PWD \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

docker exec -it -w $PWD gitlab-runner gitlab-runner exec docker hive_fork_manager
  