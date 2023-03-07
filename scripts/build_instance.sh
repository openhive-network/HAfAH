#! /bin/bash

print_help () {
    echo "Usage: $0 OPTION[=VALUE]..."
    echo
    echo "Script for building Docker image of HAfAH instance"
    echo "All options (except '--help') are required"
    echo "OPTIONS:"
    echo "  --use-postgrest=0 or 1     Whether to use Postgrest or Python backend"
    echo "  --http-port=PORT           HTTP port to be used by HAfAH"
    echo "  --haf-postgres-url=URL     HAF PostgreSQL URL, eg. 'postgresql://haf_app_admin@haf-instance:5432/haf_block_log'"
    echo "  --image-name=NAME          Docker image name to be built, eg 'registry.gitlab.syncad.com/hive/hafah/python-instance:latest'"
    echo "  --source-dir=DIR           Source directory"
    echo "  -?/--help                  Display this help screen and exit"
    echo
}

set -e

while [ $# -gt 0 ]; do
  case "$1" in
    --use-postgrest=*)
        arg="${1#*=}"
        USE_POSTGREST="$arg"
        ;;
    --http-port=*)
        arg="${1#*=}"
        APP_PORT="$arg"
        ;;
    --haf-postgres-url=*)
        arg="${1#*=}"
        HAF_POSTGRES_URL="$arg"
        ;;
    --image-name=*)
        arg="${1#*=}"
        HAFAH_IMAGE_NAME="$arg"
        ;;
    --source-dir=*)
        arg="${1#*=}"
        SOURCE_DIR="$arg"
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

[[ -z "$USE_POSTGREST" ]] && echo "Option '--use-postgrest' must be set" && print_help && exit 1
[[ -z "$APP_PORT" ]] && echo "Option '--http-port' must be set" &&  print_help && exit 1
[[ -z "$HAF_POSTGRES_URL" ]] && echo "Option '--haf-postgres-url' must be set" &&  print_help && exit 1
[[ -z "$HAFAH_IMAGE_NAME" ]] && echo "Option '--image-name' must be set" &&  print_help && exit 1
[[ -z "$SOURCE_DIR" ]] && echo "Option '--source-dir' must be set" &&  print_help && exit 1

pushd "$SOURCE_DIR"

docker build \
    --build-arg USE_POSTGREST="$USE_POSTGREST" \
    --build-arg HTTP_PORT="$APP_PORT" \
    --build-arg POSTGRES_URL="$HAF_POSTGRES_URL" \
    --target=instance \
    --tag "$HAFAH_IMAGE_NAME" \
    --file Dockerfile .

popd