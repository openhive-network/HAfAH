#! /bin/bash

print_help () {
    echo "Usage: $0 OPTION[=VALUE]..."
    echo
    echo "Script for retagging and pushing Docker image of HAfAH instance to a repository and Docker Hub"
    echo "All options (except '--help') are required"
    echo "OPTIONS:"
    echo "  --image-name=NAME             Docker image name to be pulled, eg 'registry.gitlab.syncad.com/hive/hafah/python-instance:latest'"
    echo "  --image-name-prefix=PREFIX    Docker image name prefix corresponding to registry URL, eg. 'registry.gitlab.syncad.com/hive/hafah'"
    echo "  --image-tag=TAG               Docker image tag to be used, eg. 'latest'"
    echo "  --registry-url=URL            Docker registry URL, eg 'registry.gitlab.syncad.com'"
    echo "  --registry-username=USERNAME  Docker registry username"
    echo "  --registry-password=PASSWORD  Docker registry password"
    echo "  --dockerhub-username=USERNAME Docker registry username"
    echo "  --dockerhub-password=PASSWORD Docker registry password"
    echo "  -?/--help                     Display this help screen and exit"
    echo
}

set -e

while [ $# -gt 0 ]; do
  case "$1" in
    --image-name=*)
        arg="${1#*=}"
        HAFAH_IMAGE_NAME="$arg"
        ;;
    --image-name-prefix=*)
        arg="${1#*=}"
        CI_REGISTRY_IMAGE="$arg"
        ;;
    --image-tag=*)
        arg="${1#*=}"
        CI_COMMIT_TAG="$arg"
        ;;
    --registry-url=*)
        arg="${1#*=}"
        CI_REGISTRY="$arg"
        ;;
    --registry-username=*)
        arg="${1#*=}"
        CI_REGISTRY_USER="$arg"
        ;;
    --registry-password=*)
        arg="${1#*=}"
        CI_REGISTRY_PASSWORD="$arg"
        ;;
    --dockerhub-username=*)
        arg="${1#*=}"
        DOCKER_HUB_USER="$arg"
        ;;
    --dockerhub-password=*)
        arg="${1#*=}"
        DOCKER_HUB_PASSWORD="$arg"
        ;;    
    --help)
        print_help
        exit 0
        ;;
    -?)
        print_help
        exit 0
        ;;
    *)
        echo "ERROR: '$1' is not a valid option/positional argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done    

[[ -z "$HAFAH_IMAGE_NAME" ]] && echo "Option '--image-name' must be set" && print_help && exit 1
[[ -z "$CI_REGISTRY_IMAGE" ]] && echo "Option '--image-name-prefix' must be set" && print_help && exit 1
[[ -z "$CI_COMMIT_TAG" ]] && echo "Option '--image-tag' must be set" && print_help && exit 1
[[ -z "$CI_REGISTRY" ]] && echo "Option '--registry-url' must be set" && print_help && exit 1
[[ -z "$CI_REGISTRY_USER" ]] && echo "Option '--registry-username' must be set" && print_help && exit 1
[[ -z "$CI_REGISTRY_PASSWORD" ]] && echo "Option '--registry-password' must be set" && print_help && exit 1
[[ -z "$DOCKER_HUB_USER" ]] && echo "Option '--dockerhub-username' must be set" && print_help && exit 1
[[ -z "$DOCKER_HUB_PASSWORD" ]] && echo "Option '--dockerhub-password' must be set" && print_help && exit 1

docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
docker login -u "$DOCKER_HUB_USER" -p "$DOCKER_HUB_PASSWORD"

docker pull "$HAFAH_IMAGE_NAME"

docker tag "$HAFAH_IMAGE_NAME" "$CI_REGISTRY_IMAGE/instance:instance-$CI_COMMIT_TAG"
docker tag "$HAFAH_IMAGE_NAME" "hiveio/hafah:$CI_COMMIT_TAG"

docker images

docker push "$CI_REGISTRY_IMAGE/instance:instance-$CI_COMMIT_TAG"
docker push "hiveio/hafah:$CI_COMMIT_TAG"