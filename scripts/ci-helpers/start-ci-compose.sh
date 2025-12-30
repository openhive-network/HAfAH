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
HIVED_UID=${HIVED_UID:-$(id -u)}

echo "=== Starting HAfAH CI Test Environment ==="
echo "HAF image: ${HAF_IMAGE_NAME}"
echo "HAfAH image: ${HAFAH_IMAGE_NAME}"
echo "HAF data directory: ${HAF_DATA_DIRECTORY}"
echo "HAF SHM directory: ${HAF_SHM_DIRECTORY}"
echo "HIVED_UID: ${HIVED_UID}"

# Ensure SHM directory exists
mkdir -p "${HAF_SHM_DIRECTORY}"

# Create env file for docker-compose
cat > "${CI_PROJECT_DIR}/docker/ci.env" <<EOF
HAF_IMAGE=${HAF_IMAGE_NAME}
HAFAH_IMAGE=${HAFAH_IMAGE_NAME}
HAF_DATA_DIRECTORY=${HAF_DATA_DIRECTORY}
HAF_SHM_DIRECTORY=${HAF_SHM_DIRECTORY}
HAFAH_PORT=${HAFAH_PORT}
HIVED_UID=${HIVED_UID}
EOF

echo "Generated ci.env:"
cat "${CI_PROJECT_DIR}/docker/ci.env"

cd "${CI_PROJECT_DIR}/docker"

echo "=== Docker Compose Config ==="
docker compose --env-file ci.env -f docker-compose.ci.yml config

echo "=== Starting services ==="
docker compose --env-file ci.env -f docker-compose.ci.yml up --detach --quiet-pull

echo "=== Waiting for HAfAH to be healthy ==="
echo "Initial container status:"
docker compose --env-file ci.env -f docker-compose.ci.yml ps
timeout 300 bash -c 'while true; do
  STATUS=$(docker compose --env-file ci.env -f docker-compose.ci.yml ps hafah 2>&1)
  echo "Container status: $STATUS"
  if echo "$STATUS" | grep -qi "healthy"; then
    echo "HAfAH is healthy!"
    break
  fi
  # Also check docker inspect for health status
  HEALTH=$(docker inspect --format="{{.State.Health.Status}}" hafah-ci-hafah-1 2>/dev/null || echo "unknown")
  echo "Docker health status: $HEALTH"
  if [ "$HEALTH" = "healthy" ]; then
    echo "HAfAH is healthy (via inspect)!"
    break
  fi
  sleep 5
done'

echo "=== Services started successfully ==="
docker compose --env-file ci.env -f docker-compose.ci.yml ps
