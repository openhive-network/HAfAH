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

# Supplement a registry path by trailing slash (if needed)
[[ "${REGISTRY}" != */ ]] && REGISTRY="${REGISTRY}/"

APP_PORT=${APP_PORT:-6543}
HAF_POSTGRES_URL=${HAF_POSTGRES_URL:-postgresql://hafah_user@haf:5432/haf_block_log}
HAFAH_IMAGE_NAME=${REGISTRY}instance:$HAFAH_IMAGE_TAG
HAFAH_MINIMAL_IMAGE_NAME=${REGISTRY}minimal-instance:$HAFAH_IMAGE_TAG
HAFAH_REWRITER_IMAGE_NAME=${REGISTRY}postgrest-rewriter:$HAFAH_IMAGE_TAG


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

REWRITER_TARGET=without_tag
if [ ! -z "$BUILD_IMAGE_TAG" ]; then
  REWRITER_TARGET=with_tag
  TAG_BUILD_ARGS="--build-arg GIT_COMMIT_TAG=$BUILD_IMAGE_TAG"
fi

docker buildx build \
    --build-arg HTTP_PORT="$APP_PORT" \
    --build-arg POSTGRES_URL="$HAF_POSTGRES_URL" \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    --build-arg GIT_COMMIT_SHA="$GIT_COMMIT_SHA" \
    --build-arg GIT_CURRENT_BRANCH="$GIT_CURRENT_BRANCH" \
    --build-arg GIT_LAST_LOG_MESSAGE="$GIT_LAST_LOG_MESSAGE" \
    --build-arg GIT_LAST_COMMITTER="$GIT_LAST_COMMITTER" \
    --build-arg GIT_LAST_COMMIT_DATE="$GIT_LAST_COMMIT_DATE" \
    --target=instance \
    --tag "$HAFAH_IMAGE_NAME" \
    --tag "$HAFAH_MINIMAL_IMAGE_NAME" \
    --load \
    --file Dockerfile .

docker buildx build \
    --build-arg BUILD_TIME="$BUILD_TIME" \
    --build-arg GIT_COMMIT_SHA="$GIT_COMMIT_SHA" \
    --build-arg GIT_CURRENT_BRANCH="$GIT_CURRENT_BRANCH" \
    --build-arg GIT_LAST_LOG_MESSAGE="$GIT_LAST_LOG_MESSAGE" \
    --build-arg GIT_LAST_COMMITTER="$GIT_LAST_COMMITTER" \
    --build-arg GIT_LAST_COMMIT_DATE="$GIT_LAST_COMMIT_DATE" \
    --target=$REWRITER_TARGET \
    $TAG_BUILD_ARGS \
    --tag "$HAFAH_REWRITER_IMAGE_NAME" \
    --load \
    --file Dockerfile.rewriter .


popd
