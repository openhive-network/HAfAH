# The image AIDEV runs this project's checks in (`environment.image` in
# .aidev/project.yaml). Checks run with the caller's uid and, for the slots that
# start the HAF test stack, on that stack's network; every tool is in the image,
# taken from the images this project's own Dockerfile builds HAfAH from:
#
#   psql:14-1 (the PSQL_CLIENT_VERSION base of ./Dockerfile; Alpine, bash, psql)
#   + the postgrest binary of postgrest:v12.0.2 (POSTGREST_VERSION there)
#   + python3 (junit writer, API smoke test) and shellcheck from Alpine's repository.
#
# Build and pin it with .aidev/runtime/build.sh; see .aidev/README.md.
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/postgrest@sha256:928a9478f8a4b38dab3448846bf40da3f2075ae770c3f94fb9760ff689aa6561 AS postgrest

FROM registry.gitlab.syncad.com/hive/common-ci-configuration/psql@sha256:176d4a7d19d83d09f3b2e4e9b3a38df1e3bc01492f4b3a1e7352ac0945518f07

USER root
RUN apk add --no-cache python3 shellcheck

COPY --from=postgrest /bin/postgrest /usr/local/bin/postgrest

ENV HOME=/tmp
ENTRYPOINT []
CMD ["bash"]
