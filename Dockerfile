# syntax=docker/dockerfile:1.5

ARG POSTGREST_VERSION=v12.0.2

FROM postgrest/postgrest:${POSTGREST_VERSION} AS pure_postgrest

FROM alpine:3.19 AS runtime

RUN apk add --no-cache bash coreutils ca-certificates postgresql-client sudo
RUN adduser -D "haf_admin" && echo "haf_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    adduser -D "hafah_user" && chmod -R a+w /home/hafah_user

SHELL ["/bin/bash", "-c"]

ENV LANG=en_US.UTF-8

COPY --chmod=755 --from=pure_postgrest /bin/postgrest /usr/local/bin

USER hafah_user
WORKDIR /home/hafah_user

SHELL ["/bin/bash", "-c"]

FROM runtime AS instance

ARG BUILD_TIME
ARG GIT_COMMIT_SHA
ARG GIT_CURRENT_BRANCH
ARG GIT_LAST_LOG_MESSAGE
ARG GIT_LAST_COMMITTER
ARG GIT_LAST_COMMIT_DATE
LABEL org.opencontainers.image.created="$BUILD_TIME"
LABEL org.opencontainers.image.url="https://hive.io/"
LABEL org.opencontainers.image.documentation="https://gitlab.syncad.com/hive/HAfAH"
LABEL org.opencontainers.image.source="https://gitlab.syncad.com/hive/HAfAH"
#LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="$GIT_COMMIT_SHA"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.ref.name="HAfAH"
LABEL org.opencontainers.image.title="HAF Account History (HAfAH) Image"
LABEL org.opencontainers.image.description="Runs HAfAH application"
LABEL io.hive.image.branch="$GIT_CURRENT_BRANCH"
LABEL io.hive.image.commit.log_message="$GIT_LAST_LOG_MESSAGE"
LABEL io.hive.image.commit.author="$GIT_LAST_COMMITTER"
LABEL io.hive.image.commit.date="$GIT_LAST_COMMIT_DATE"

ARG HTTP_PORT=6543
ENV HTTP_PORT=${HTTP_PORT}

ARG POSTGRES_URL="postgresql://hafah_user@haf/haf_block_log"
ENV POSTGRES_URL=${POSTGRES_URL}

ARG USE_POSTGREST=1
ENV USE_POSTGREST=${USE_POSTGREST}

ENV PGRST_DB_SCHEMA="hafah_endpoints"
ENV PGRST_DB_ANON_ROLE="hafah_user"
ENV PGRST_DB_ROOT_SPEC="home"

ENV LANG=en_US.UTF-8

USER hafah_user
WORKDIR /home/hafah_user

SHELL ["/bin/bash", "-c"]

ADD --chown=hafah_user:hafah_user ./postgrest/ ./app/postgrest
ADD --chown=hafah_user:hafah_user ./queries/ ./app/queries
ADD --chmod=755 --chown=hafah_user:hafah_user ./scripts ./app/scripts
ADD --chmod=755 --chown=hafah_user:hafah_user ./haf/scripts ./app/haf/scripts

ADD --chmod=755 --chown=hafah_user:hafah_user ./docker/docker_entrypoint.sh .

USER haf_admin

# JSON rpc service
EXPOSE ${HTTP_PORT}

STOPSIGNAL SIGINT

ENTRYPOINT [ "/home/hafah_user/docker_entrypoint.sh" ]
