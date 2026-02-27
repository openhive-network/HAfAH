#! /bin/bash

print_help () {
cat <<EOF
Usage: $0 <image_tag> <src_dir> <registry_url> [OPTION[=VALUE]]...

Script for building Docker image of HAfAH instance
OPTIONS:
  --use-postgrest=0 or 1     Compatibility only - allows to use Postgrest backend (default: 1)
  --http-port=PORT           HTTP port to be used by HAfAH (default: 6543)
  --haf-postgres-url=URL     HAF PostgreSQL URL, (default: postgresql://hafah_user@haf:5432/haf_block_log)
  -?/--help                  Display this help screen and exit

EOF
}

set -e

while [ $# -gt 0 ]; do
  case "$1" in
    --use-postgrest=*)
        ;;
    --http-port=*)
        arg="${1#*=}"
        APP_PORT="$arg"
        ;;
    --haf-postgres-url=*)
        arg="${1#*=}"
        HAF_POSTGRES_URL="$arg"
        ;;
    -?|--help)
        print_help
        exit 0
        ;;
    *)
        if [ -z "$BUILD_IMAGE_TAG" ];
        then
          BUILD_IMAGE_TAG="$1"
        elif [ -z "$SRCROOTDIR" ];
        then
          SRCROOTDIR="$1"
        elif [ -z "$REG" ];
        then
          REG="$1"
        else
            printf "ERROR: '%s' is not a valid option/positional argument\n" "$1"
            print_help
            exit 2
        fi
        ;;
    esac
    shift
done

HAFAH_IMAGE_TAG=${BUILD_IMAGE_TAG:-$HAFAH_IMAGE_TAG}
SOURCE_DIR=${SRCROOTDIR:-$SOURCE_DIR}
REGISTRY=${REG:-$REGISTRY}

[[ -z "$HAFAH_IMAGE_TAG" ]] && printf "Image tag must be provided\n" &&  print_help && exit 1
[[ -z "$SOURCE_DIR" ]] && printf "Source directroy must be provided\n" &&  print_help && exit 1
[[ -z "$REGISTRY" ]] && printf "Docker registry URL must be provided\n" &&  print_help && exit 1

APP_PORT=${APP_PORT:-6543}
HAF_POSTGRES_URL=${HAF_POSTGRES_URL:-postgresql://hafah_user@haf:5432/haf_block_log}

# On CI push the images to the registry
if [[ -n "${CI:-}" ]]; then
  BUILD_MODE="--push"
else
  BUILD_MODE="--load"
fi

# Build image tags
HAFAH_IMAGE_NAME=${REGISTRY}:$HAFAH_IMAGE_TAG
HAFAH_REWRITER_IMAGE_NAME=${REGISTRY}/postgrest-rewriter:$HAFAH_IMAGE_TAG

# Additional tags for images
MAIN_TAGS=("--tag" "$HAFAH_IMAGE_NAME")
REWRITER_TAGS=("--tag" "$HAFAH_REWRITER_IMAGE_NAME")

# Add 'latest' tags on develop branch
if [[ "${CI_COMMIT_BRANCH:-}" == "${CI_DEFAULT_BRANCH:-develop}" ]]; then
  MAIN_TAGS+=("--tag" "${REGISTRY}:latest")
  REWRITER_TAGS+=("--tag" "${REGISTRY}/postgrest-rewriter:latest")
fi

# Add version tags on protected tags
if [[ -n "${CI_COMMIT_TAG:-}" && "${CI_COMMIT_REF_PROTECTED:-}" == "true" ]]; then
  MAIN_TAGS+=("--tag" "${REGISTRY}:${CI_COMMIT_TAG}")
  REWRITER_TAGS+=("--tag" "${REGISTRY}/postgrest-rewriter:${CI_COMMIT_TAG}")
fi


printf "Parameter values:\n - SOURCE_DIR: %s\n - APP_PORT: %d\n - HAF_POSTGRES_URL: %s\n - HAFAH_IMAGE_NAME: %s\n\n" \
    "$SOURCE_DIR" "$APP_PORT" "$HAF_POSTGRES_URL" "$HAFAH_IMAGE_NAME"

pushd "$SOURCE_DIR"

bash "./scripts/generate_version_sql.bash" "$(pwd)"

BUILD_TIME="$(date -uIseconds)"

GIT_COMMIT_SHA="$(git rev-parse HEAD || true)"
if [ -z "$GIT_COMMIT_SHA" ]; then
  GIT_COMMIT_SHA="[unknown]"
fi

GIT_CURRENT_BRANCH="$(git branch --show-current || true)"
if [ -z "$GIT_CURRENT_BRANCH" ]; then
  GIT_CURRENT_BRANCH="$(git describe --abbrev=0 --all --exclude 'pipelines/*' | sed 's/^.*\///' || true)"
  if [ -z "$GIT_CURRENT_BRANCH" ]; then
    GIT_CURRENT_BRANCH="[unknown]"
  fi
fi

GIT_LAST_LOG_MESSAGE="$(git log -1 --pretty=%B || true)"
if [ -z "$GIT_LAST_LOG_MESSAGE" ]; then
  GIT_LAST_LOG_MESSAGE="[unknown]"
fi

GIT_LAST_COMMITTER="$(git log -1 --pretty="%an <%ae>" || true)"
if [ -z "$GIT_LAST_COMMITTER" ]; then
  GIT_LAST_COMMITTER="[unknown]"
fi

GIT_LAST_COMMIT_DATE="$(git log -1 --pretty="%aI" || true)"
if [ -z "$GIT_LAST_COMMIT_DATE" ]; then
  GIT_LAST_COMMIT_DATE="[unknown]"
fi

# Resolve API version from git tags for OpenAPI spec injection
git fetch --tags --quiet 2>/dev/null || true
API_VERSION="$(git describe --tags 2>/dev/null || echo 0.0.0-dev)"

echo "Building HAfAH image..."

docker buildx build \
    --build-arg HTTP_PORT="$APP_PORT" \
    --build-arg POSTGRES_URL="$HAF_POSTGRES_URL" \
    --build-arg API_VERSION="$API_VERSION" \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    --build-arg GIT_COMMIT_SHA="$GIT_COMMIT_SHA" \
    --build-arg GIT_CURRENT_BRANCH="$GIT_CURRENT_BRANCH" \
    --build-arg GIT_LAST_LOG_MESSAGE="$GIT_LAST_LOG_MESSAGE" \
    --build-arg GIT_LAST_COMMITTER="$GIT_LAST_COMMITTER" \
    --build-arg GIT_LAST_COMMIT_DATE="$GIT_LAST_COMMIT_DATE" \
    --target=instance \
    "${MAIN_TAGS[@]}" \
    $BUILD_MODE \
    --file Dockerfile .

echo -e "Done!\nBuilding rewriter image..."

docker buildx build \
    --build-arg API_VERSION="$API_VERSION" \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    --build-arg GIT_COMMIT_SHA="$GIT_COMMIT_SHA" \
    --build-arg GIT_CURRENT_BRANCH="$GIT_CURRENT_BRANCH" \
    --build-arg GIT_LAST_LOG_MESSAGE="$GIT_LAST_LOG_MESSAGE" \
    --build-arg GIT_LAST_COMMITTER="$GIT_LAST_COMMITTER" \
    --build-arg GIT_LAST_COMMIT_DATE="$GIT_LAST_COMMIT_DATE" \
    "${REWRITER_TAGS[@]}" \
    $BUILD_MODE \
    --file Dockerfile.rewriter .

echo "Done!"

popd
