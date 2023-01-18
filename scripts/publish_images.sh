#! /bin/bash

[[ -z "$DOCKER_HUB_USER" ]] && echo "Variable DOCKER_HUB_USER must be set" && exit 1
[[ -z "$DOCKER_HUB_PASSWORD" ]] && echo "Variable DOCKER_HUB_PASSWORD must be set" && exit 1
[[ -z "$HAFAH_IMAGE_NAME" ]] && echo "Variable HAFAH_IMAGE_NAME must be set" && exit 1

set -e

docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
#docker login -u "$DOCKER_HUB_USER" -p "$DOCKER_HUB_PASSWORD"

docker pull "$HAFAH_IMAGE_NAME"

docker tag "$HAFAH_IMAGE_NAME" "${CI_REGISTRY_IMAGE}/instance:instance-${CI_COMMIT_TAG}"
docker tag "$HAFAH_IMAGE_NAME" "hiveio/hafah:${CI_COMMIT_TAG}"

docker push "${CI_REGISTRY_IMAGE}/instance:instance-${CI_COMMIT_TAG}"
#docker push "hiveio/hafah:${CI_COMMIT_TAG}"