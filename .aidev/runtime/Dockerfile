# The image AIDEV runs this project's checks in. AIDEV builds it on the base
# .aidev/project.yaml's `environment.base` follows (common-ci-configuration's
# python-test-tools:develop) and rebuilds it when that tag moves. Checks run with
# the caller's uid and, for the slots that reach the shared HAF, on the per-run
# network its relay is on; nothing is installed at run time.
#
# The base brings every tool at common-ci-configuration's docker-bake.hcl versions:
# Python 3.14, tavern, pytest, pytest-xdist, deepdiff, bash, psql, shellcheck and
# the postgrest binary. This file adds only hive/tests_api (validate_response, the
# tavern tests' comparator) at TESTS_API_COMMIT, without its dependencies so the
# base's tool versions stay as they are.
#
# See .aidev/README.md.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG TESTS_API_COMMIT=455898cc3462d4e5ee2274756e5e3d44688fe204

RUN pip install --no-cache-dir --no-deps --root-user-action=ignore \
        "https://gitlab.syncad.com/hive/tests_api/-/archive/${TESTS_API_COMMIT}/tests_api-${TESTS_API_COMMIT}.tar.gz"

ENV HOME=/tmp
ENTRYPOINT []
CMD ["bash"]
