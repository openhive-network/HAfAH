#! /bin/bash

[[ -z "$SOURCE_DIR" ]] && echo "Variable SOURCE_DIR must be set" && exit 1
[[ -z "$HAFAH_CI_IMG_BUILDER_PASSWORD" ]] && echo "Variable HAFAH_CI_IMG_BUILDER_PASSWORD must be set" && exit 1
[[ -z "$HAFAH_CI_IMG_BUILDER_USER" ]] && echo "Variable HAFAH_CI_IMG_BUILDER_USER must be set" && exit 1
[[ -z "$REGISTRY" ]] && echo "Variable REGISTRY must be set" && exit 1

set -e

SCRIPTPATH=$(dirname "$(realpath "$0")")

"$SCRIPTPATH/build_instance.sh"

echo "$HAFAH_CI_IMG_BUILDER_PASSWORD" | docker login -u "$HAFAH_CI_IMG_BUILDER_USER" "$REGISTRY" --password-stdin

docker push "$HAFAH_IMAGE_NAME"

echo "HAFAH_IMAGE_NAME=$HAFAH_IMAGE_NAME" > docker_image_name.env