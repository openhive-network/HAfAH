# The image AIDEV runs this project's checks in (`environment.image` in
# .aidev/project.yaml). Checks run with the caller's uid and, for the slots that
# reach the shared HAF, on the per-run network its relay is on; every tool is in
# the image, nothing is installed at run time:
#
#   python:3.14-alpine (hive/tests_api requires Python >= 3.14, as CI's
#   hafah_pytest_rest_api_pattern_tests runs it on python:3.14-slim)
#   + the postgrest binary of postgrest:v12.0.2 (POSTGREST_VERSION in ./Dockerfile)
#   + bash, psql, shellcheck from Alpine's repository
#   + tavern, pytest and pytest-xdist, and hive/tests_api (validate_response, the tavern
#     tests' comparator) at TESTS_API_COMMIT.
#
# Build and pin it with .aidev/runtime/build.sh; see .aidev/README.md.
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/postgrest@sha256:928a9478f8a4b38dab3448846bf40da3f2075ae770c3f94fb9760ff689aa6561 AS postgrest

FROM python:3.14-alpine@sha256:f6a589d43c42b9e7f7dc67a12d37132491f362859a5d750607710cc56da3bc72

ARG TESTS_API_COMMIT=455898cc3462d4e5ee2274756e5e3d44688fe204

RUN apk add --no-cache bash postgresql-client shellcheck

RUN pip install --no-cache-dir --root-user-action=ignore \
        tavern==3.7.0 \
        pytest==9.1.1 \
        pytest-xdist==3.8.0 \
        "https://gitlab.syncad.com/hive/tests_api/-/archive/${TESTS_API_COMMIT}/tests_api-${TESTS_API_COMMIT}.tar.gz"

COPY --from=postgrest /bin/postgrest /usr/local/bin/postgrest

ENV HOME=/tmp
ENTRYPOINT []
CMD ["bash"]
