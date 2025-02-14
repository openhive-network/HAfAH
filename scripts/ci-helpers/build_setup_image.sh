#!/bin/bash

set -e

SRC_DIR="${1:?"This script needs Hivemind source directory path as its first parameter"}"
TAG="${CI_REGISTRY_IMAGE:?"registry.gitlab.syncad.com/hive/hafah"}/setup:${CI_COMMIT_SHORT_SHA:?"latest"}"

pushd "${SRC_DIR}"

echo "TRUNCATE TABLE hafah_python.version; INSERT INTO hafah_python.version(git_hash) VALUES ('$(git rev-parse HEAD)');" > set_version_in_sql.pgsql

docker buildx build --tag="${TAG}" -f Dockerfile.setup .

if [ -n "${CI:-}" ]; then
    docker push "${TAG}"
fi

popd
