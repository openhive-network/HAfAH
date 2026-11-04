#!/bin/bash
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CI_PROJECT_DIR=${CI_PROJECT_DIR:-$SCRIPTPATH/../..}

# Required environment variables
: "${HAF_IMAGE_NAME:?HAF_IMAGE_NAME must be set}"
: "${HAFAH_IMAGE_NAME:?HAFAH_IMAGE_NAME must be set}"
: "${HAF_DATA_DIRECTORY:?HAF_DATA_DIRECTORY must be set}"

# Optional with defaults
HAF_SHM_DIRECTORY=${HAF_SHM_DIRECTORY:-${HAF_DATA_DIRECTORY}/shm_dir}
HAFAH_PORT=${HAFAH_PORT:-6543}
# Address the tests reach HAfAH at (the job's HAF_APP_HOST/HAF_APP_PORT)
HAFAH_TEST_URL="http://${HAF_APP_HOST:-localhost}:${HAF_APP_PORT:-${HAFAH_PORT}}"
READINESS_TIMEOUT=${READINESS_TIMEOUT:-300}
echo "=== Starting HAfAH CI Test Environment ==="
echo "HAF image: ${HAF_IMAGE_NAME}"
echo "HAfAH image: ${HAFAH_IMAGE_NAME}"
echo "HAF data directory: ${HAF_DATA_DIRECTORY}"
echo "HAF SHM directory: ${HAF_SHM_DIRECTORY}"

# Ensure SHM directory exists
mkdir -p "${HAF_SHM_DIRECTORY}"

# Create env file for docker-compose
cat > "${CI_PROJECT_DIR}/docker/ci.env" <<EOF
HAF_IMAGE=${HAF_IMAGE_NAME}
HAFAH_IMAGE=${HAFAH_IMAGE_NAME}
HAF_DATA_DIRECTORY=${HAF_DATA_DIRECTORY}
HAF_SHM_DIRECTORY=${HAF_SHM_DIRECTORY}
HAFAH_PORT=${HAFAH_PORT}
EOF

echo "Generated ci.env:"
cat "${CI_PROJECT_DIR}/docker/ci.env"

cd "${CI_PROJECT_DIR}/docker"

echo "=== Docker Compose Config ==="
docker compose --env-file ci.env -f docker-compose.ci.yml config

echo "=== Starting services ==="
docker compose --env-file ci.env -f docker-compose.ci.yml up --detach --quiet-pull

echo "=== Waiting for HAfAH to be healthy ==="
timeout "${READINESS_TIMEOUT}" bash -c 'until docker compose --env-file ci.env -f docker-compose.ci.yml ps hafah 2>&1 | grep -q "(healthy)"; do echo "Waiting for hafah..."; sleep 5; done'
echo "HAfAH is healthy!"

# The container's health check runs inside it; the tests connect from this container
# through the published port, so probe the same address and request they use.
echo "=== Waiting for HAfAH at ${HAFAH_TEST_URL} ==="
if ! timeout "${READINESS_TIMEOUT}" bash -c 'until curl -fsS -o /dev/null --max-time 5 -X POST -H "Content-Type: application/json" -d "{}" "$1/rpc/get_head_block_num"; do echo "Waiting for ${1}..."; sleep 5; done' _ "${HAFAH_TEST_URL}"; then
  echo "ERROR: HAfAH is not reachable at ${HAFAH_TEST_URL} after ${READINESS_TIMEOUT}s"
  docker compose --env-file ci.env -f docker-compose.ci.yml ps
  docker compose --env-file ci.env -f docker-compose.ci.yml logs hafah | tail -50
  exit 1
fi
echo "HAfAH is reachable at ${HAFAH_TEST_URL}"

echo "=== Services started successfully ==="
docker compose --env-file ci.env -f docker-compose.ci.yml ps
