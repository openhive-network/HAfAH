#! /bin/bash

[[ -z "$USE_POSTGREST" ]] && echo "Variable USE_POSTGREST must be set" && exit 1
[[ -z "$APP_PORT" ]] && echo "Variable APP_PORT must be set" && exit 1
[[ -z "$HAF_POSTGRES_URL" ]] && echo "Variable HAF_POSTGRES_URL must be set" && exit 1
[[ -z "$HAFAH_IMAGE_NAME" ]] && echo "Variable HAFAH_IMAGE_NAME must be set" && exit 1
[[ -z "$SOURCE_DIR" ]] && echo "Variable SOURCE_DIR must be set" && exit 1

set -e

pushd "$SOURCE_DIR"

docker build --build-arg USE_POSTGREST="$USE_POSTGREST" \
    --build-arg HTTP_PORT="$APP_PORT" \
    --build-arg POSTGRES_URL="$HAF_POSTGRES_URL" \
    --target=instance \
    --tag "$HAFAH_IMAGE_NAME" \
    --file Dockerfile .

popd