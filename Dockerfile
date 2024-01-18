# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/hafah/ci-base-image:ubuntu20.04-xxx -f Dockerfile .

ARG POSTGREST_VERSION=v12.0.2

ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah
ARG CI_IMAGE_TAG=:ubuntu20.04-6

# As described here, better to avoid Apline images usage together with Python...

FROM python:3.8-slim as ci-base-image

ENV LANG=en_US.UTF-8

RUN apt update && DEBIAN_FRONTEND=noniteractive apt install -y  \
  bash \
  joe \
  sudo \
  git \
  ca-certificates \
  postgresql-client \
  wget \
  procps \
  xz-utils \
  && DEBIAN_FRONTEND=noniteractive apt-get clean && rm -rf /var/lib/apt/lists/* \
  && useradd -ms /bin/bash "haf_admin" && echo "haf_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && useradd -ms /bin/bash "haf_app_admin" \
  && useradd -ms /bin/bash "hafah_user"

SHELL ["/bin/bash", "-c"]

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
