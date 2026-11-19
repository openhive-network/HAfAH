# The image AIDEV runs this project's checks in. AIDEV builds it on the base
# .aidev/project.yaml's `environment.base` follows (common-ci-configuration's
# python-test-tools:develop) and rebuilds it when that tag moves. Checks run with
# the caller's uid and, for the slots that reach the shared HAF, on the per-run
# network its relay is on; nothing is installed at run time.
#
# The base brings every tool at common-ci-configuration's docker-bake.hcl versions:
# Python 3.14, tavern, pytest, pytest-xdist, deepdiff, bash, psql, shellcheck and
# the postgrest binary. This file adds hive/tests_api (validate_response, the
# tavern tests' comparator) at TESTS_API_COMMIT, without its dependencies so the
# base's tool versions stay as they are, and, for the rewriter step, the OpenResty of
# the rewriter image's base (Dockerfile.rewriter's FROM names the same digest: move
# both together), and, for scripts/install_app.sh's install lock, common-ci-configuration's
# install_with_app_lock.py from the psql image the hafah Dockerfile builds on (its
# PSQL_CLIENT_VERSION tag, here by digest: move both together) with the psycopg2 it
# imports, so the install steps take the lock as the hafah image does. That OpenResty is
# built against Alpine's musl, so musl's loader and the two Alpine libraries it links
# besides its own (zlib, libgcc_s) come too, in a directory only musl's loader reads.
#
# See .aidev/README.md.
ARG BASE_IMAGE
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/nginx@sha256:e173b651aff04b3735f870068549281c417801ea64b192cf7c8cc4bce5a91815 AS rewriter

FROM registry.gitlab.syncad.com/hive/common-ci-configuration/psql@sha256:bf3f0974b0bccfff22060bccfd7cbe469f56e757d8b07535f8ee8b4288e0be67 AS psql

FROM ${BASE_IMAGE}

ARG TESTS_API_COMMIT=455898cc3462d4e5ee2274756e5e3d44688fe204

RUN pip install --no-cache-dir --no-deps --root-user-action=ignore \
        "https://gitlab.syncad.com/hive/tests_api/-/archive/${TESTS_API_COMMIT}/tests_api-${TESTS_API_COMMIT}.tar.gz" \
    && pip install --no-cache-dir --root-user-action=ignore psycopg2-binary

COPY --from=psql /usr/local/bin/install_with_app_lock.py /usr/local/bin/install_with_app_lock.py

COPY --from=rewriter /usr/local/openresty /usr/local/openresty
COPY --from=rewriter /lib/ld-musl-x86_64.so.1 /usr/lib/ld-musl-x86_64.so.1
COPY --from=rewriter /lib/ld-musl-x86_64.so.1 /opt/musl/lib/libc.musl-x86_64.so.1
COPY --from=rewriter /usr/lib/libz.so.1.3.1 /opt/musl/lib/libz.so.1
COPY --from=rewriter /usr/lib/libgcc_s.so.1 /opt/musl/lib/libgcc_s.so.1
RUN echo /opt/musl/lib > /etc/ld-musl-x86_64.path \
    && /usr/local/openresty/bin/openresty -v

ENV HOME=/tmp
ENTRYPOINT []
CMD ["bash"]
